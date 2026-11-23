# Makes the smallest Gemfile.lock change that clears a repo's open findings, and opens or
# updates its one Pitcrew PR. This class decides and orchestrates; the work is elsewhere:
#
#   1. Refresh the open PR from GitHub (the DB copy can be minutes stale).
#   2. Shallow-clone (read-only) into the shared work dir: the default branch for a new PR;
#      for an open PR, its own branch, after merging the default branch into it server-side
#      when the default branch's lockfile moved (Github::MergeDefaultBranch). Whatever people
#      pushed to the PR branch is the starting point and carries forward.
#   3. Resolve in the sidecar for the checkout's Ruby minor (Fix::Resolve).
#   4. Only Gemfile.lock may change. Work out what that achieved (Fix::Analyze), commit it
#      via the API on top of the checkout (Github::CommitLockfile), open or update the PR,
#      and record it: findings move to in_pr; anything still flagged -> needs_attention.
class RepositoryFix < ApplicationService
  UnexpectedChanges = Class.new(StandardError)

  def self.work_root
    Pathname(ENV.fetch("PITCREW_WORK_DIR", Rails.root.join("tmp/work").to_s))
  end

  # force: refresh an open PR even with no new findings (e.g. the default branch's
  # lockfile changed, so the PR needs it merged in, or a kept-current gem has a release).
  def call(repository:, force: false)
    @repository = repository
    @client = Github::InstallationClient.call(installation_id: repository.installation_id)
    @pull_request = refresh_open_pr
    @behind = repository.behind_gems

    unless candidates.exists? || @behind.any?
      close_pull_request if @pull_request
      return { result: "nothing to fix" }
    end
    return { result: "up to date" } if @pull_request && !force && !findings.open.exists?

    with_checkout do |dir, base|
      ruby_minor = checkout_ruby_minor(dir)
      if Resolver::Client.available?(ruby_minor)
        fix(dir, base, ruby_minor)
      else
        reason = "No resolver for Ruby #{ruby_minor || '(unknown)'}. Add a sidecar for it."
        findings.open.each { it.flag!(reason) }
        { result: "no resolver" }
      end
    end
  end

  private

  def findings
    @repository.findings
  end

  # What this run may put in the PR: open findings, plus the ones already in the current
  # open PR. Not needs_attention (a human has to look, e.g. they closed the PR), and not
  # in_pr findings of a merged PR (the next scan resolves those).
  def candidates
    findings.open.or(findings.in_pr.where(fix_pull_request_id: @pull_request&.id || 0)).includes(:advisory)
  end

  def refresh_open_pr
    pull_request = @repository.open_fix_pull_request
    return unless pull_request

    pull_request if PullRequestSync.call(pull_request:, client: @client, with_ci: false).open?
  end

  def with_checkout
    FileUtils.mkdir_p(self.class.work_root)
    dir = self.class.work_root.join(SecureRandom.hex(8))
    if @pull_request
      Github::MergeDefaultBranch.call(client: @client, repository: @repository, branch: @pull_request.branch)
      base = Github::Checkout.call(repository: @repository, dir: dir.to_s, branch: @pull_request.branch)
      # Seen: this head (people's pushes, our merge of the default branch) is now Pitcrew's
      # starting point, so the PR poll shouldn't treat it as someone else's push.
      @pull_request.update!(head_sha: base[:head])
    else
      base = Github::Checkout.call(repository: @repository, dir: dir.to_s)
    end
    yield dir, base
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # The Ruby the checkout itself declares picks the resolver: an open PR's branch can be on
  # a newer Ruby than the default branch (the upgrade lives there until it merges). Falls
  # back to the default branch's, from the last scan, then the repo's ruby_minor (set in the
  # UI for repos that declare none). Not written back: runtimes describe the default branch.
  def checkout_ruby_minor(dir)
    file = dir.join(".ruby-version")
    version = Repository.ruby_version_from(file.read(100)) if file.file? && !file.symlink?
    version ? Repository.minor_of(:ruby, version) : @repository.runtime_minor(:ruby)
  end

  def fix(dir, base, ruby_minor)
    original = dir.join("Gemfile.lock").read
    ignore = ignore_list(dir)
    # needs_attention findings are left alone too, so declining a PR (closing it) sticks.
    resolve_ignore = ignore + findings.needs_attention.includes(:advisory).map { it.advisory.identifier }
    updated = Fix::Resolve.call(
      repository: @repository, dir:, ruby_minor:, ignore: resolve_ignore, behind: @behind, token: base[:token]
    )
    ensure_only_lockfile_changed!(dir)

    outcome = Fix::Analyze.call(
      candidates: candidates.to_a, findings: findings.includes(:advisory).to_a,
      still_flagged: Lockfile::Audit.call(content: updated, ignore:),
      default_lockfile: @pull_request ? Github::RepoFile.call(repository: @repository, path: "Gemfile.lock")[:content] : original,
      original:, updated:, behind: @behind, pull_request: @pull_request
    )
    if outcome.empty?(new_pr: @pull_request.nil?)
      flag(outcome.blocked)
      return { result: "nothing resolvable", blocked: outcome.blocked.size }
    end

    publish(outcome, updated, base)
  end

  def publish(outcome, updated, base)
    content = PullRequestContent.new(
      repository: @repository, fixed: outcome.fixed_gems, companion: outcome.companion,
      blocked: outcome.blocked, kept_current: outcome.kept
    )
    kind = @pull_request ? "pr_updated" : "pr_opened"
    branch = @pull_request&.branch || FixPullRequest.branch_name
    sha = Github::CommitLockfile.call(
      client: @client, repository: @repository, branch:, lockfile: updated, base:,
      message: outcome.update_message || content.title, new_branch: @pull_request.nil?
    )

    if @pull_request
      Github::UpdatePullRequest.call(
        client: @client, repository: @repository, number: @pull_request.number, title: content.title, body: content.body
      )
      if sha.nil? # the branch already has exactly this; only the title/body may have changed
        record(outcome, kind)
        return { result: "up to date", pr: @pull_request.number }
      end
      @pull_request.update!(head_sha: sha)
    else
      number = Github::OpenPullRequest.call(client: @client, repository: @repository, branch:, title: content.title, body: content.body)
      @pull_request = @repository.fix_pull_requests.create!(number:, branch:, state: "open", head_sha: sha, opened_at: Time.current)
    end

    record(outcome, kind)
    { result: kind, pr: @pull_request.number, fixed: outcome.fixed.size, bumped: outcome.bumps.size, blocked: outcome.blocked.size }
  end

  def record(outcome, kind)
    now = Time.current
    ActiveRecord::Base.transaction do
      record_bumps(outcome.bumps)
      outcome.fixed.each { it.move_to_pr!(@pull_request, kind, at: now) }
      flag(outcome.blocked)
    end
  end

  # The PR's bumps are exactly what its lockfile carries over the default branch.
  def record_bumps(bumps)
    @pull_request.gem_bumps.where.not(gem_name: bumps.map(&:name)).delete_all
    bumps.each do |gem|
      @pull_request.gem_bumps.find_or_initialize_by(gem_name: gem.name)
        .update!(repository: @repository, from_version: gem.from, to_version: gem.to)
    end
  end

  def flag(blocked)
    blocked.each { it.finding.flag!(it.reason) }
  end

  def close_pull_request
    Github::ClosePullRequest.call(
      client: @client, repository: @repository, number: @pull_request.number,
      comment: "Closing: the default branch no longer needs any of these changes."
    )
    PullRequestSync.call(pull_request: @pull_request, client: @client, with_ci: false)
  end

  def ensure_only_lockfile_changed!(dir)
    # Bare filenames (porcelain's status columns don't survive Command's strip).
    changed = [
      Command.run!("git", "diff", "--name-only", chdir: dir),
      Command.run!("git", "ls-files", "--others", "--exclude-standard", chdir: dir)
    ].flat_map(&:lines).map(&:strip).reject(&:empty?)
    unexpected = changed - ["Gemfile.lock"]
    raise UnexpectedChanges, "resolving changed more than Gemfile.lock: #{unexpected.join(', ')}" if unexpected.any?
  end

  def ignore_list(dir)
    path = Lockfile::Audit::CONFIG_PATHS.map { dir.join(it) }.find(&:file?)
    path ? Lockfile::Audit.ignore_list(path.read) : []
  end
end
