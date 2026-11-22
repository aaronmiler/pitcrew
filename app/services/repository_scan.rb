# Audits a repo's Gemfile.lock (from its default branch, no clone) against the local
# ruby-advisory-db, and records the result as findings + events:
#   - new or re-appearing advisory -> finding opened, `detected` event
#   - advisory gone from the lockfile -> finding resolved, `resolved` event
# Skips the audit when the lockfile hasn't changed, unless forced (new advisories) or the
# repo has no locked_versions yet (kept-current gems are compared against them).
# Advisories the repo ignores in its bundler-audit config are skipped, like `bundle audit` does.
class RepositoryScan < ApplicationService
  def call(repository:, force: false)
    @repository = repository
    lockfile = Github::RepoFile.call(repository:, path: "Gemfile.lock")
    return { skipped: "no Gemfile.lock" } unless lockfile
    if !force && lockfile[:sha] == repository.lockfile_sha && repository.locked_versions.present?
      return { skipped: "lockfile unchanged" }
    end

    # The first recording of locked_versions counts as a change, so kept-current gems get checked.
    lockfile_changed = lockfile[:sha] != repository.lockfile_sha || repository.locked_versions.blank?
    results = Lockfile::Audit.call(content: lockfile[:content], ignore: ignored)
    summary = ActiveRecord::Base.transaction { record(results) }
    repository.update!(
      lockfile_sha: lockfile[:sha], runtimes: repository.with_runtime(:ruby, ruby_version), last_scanned_at: Time.current,
      locked_versions: Lockfile::Versions.new(lockfile[:content]).versions
    )
    summary.merge(lockfile_changed:)
  end

  private

  def record(results)
    now = Time.current
    detected = 0

    current_ids = results.filter_map do |result|
      advisory = Advisory.find_by(ecosystem: "rubygems", package_name: result.gem.name, source_id: result.advisory.id)
      unless advisory
        Rails.logger.warn("[RepositoryScan] #{result.advisory.id} isn't imported yet; skipping")
        next
      end

      finding = @repository.findings.find_or_initialize_by(advisory:)
      locked_version = result.gem.version.to_s
      if finding.new_record? || finding.resolved?
        finding.detect!(locked_version, at: now)
        detected += 1
      else
        finding.update!(locked_version:)
      end
      finding.id
    end.uniq

    gone = @repository.findings.where.not(status: "resolved").where.not(id: current_ids)
    resolved = gone.count
    gone.find_each { it.resolve!(at: now) }

    { detected:, resolved:, open: current_ids.size }
  end

  def ignored
    Lockfile::Audit::CONFIG_PATHS.each do |path|
      file = Github::RepoFile.call(repository: @repository, path:)
      return Lockfile::Audit.ignore_list(file[:content]) if file
    end
    []
  end

  def ruby_version
    Repository.ruby_version_from(Github::RepoFile.call(repository: @repository, path: ".ruby-version")&.dig(:content))
  end
end
