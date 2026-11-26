# Audits a repo's Gemfile.lock (from its default branch, no clone) against the local
# ruby-advisory-db, and records the result as findings + events:
#   - new or re-appearing advisory -> finding opened, `detected` event
#   - advisory gone from the lockfile -> finding resolved, `resolved` event
# Skips the audit when neither the lockfile nor the advisory db has changed since the last
# audit, unless forced or the repo has no locked_versions yet (kept-current gems are compared
# against them). Comparing the advisory-db commit means a failed rescan after new advisories
# retries on the next scheduled scan instead of waiting for the next advisory.
# Advisories the repo ignores in its bundler-audit config are skipped, like `bundle audit` does.
# Every scan, skipped or not, is recorded in `last_scan` so the UI can show what was checked.
class RepositoryScan < ApplicationService
  def call(repository:, force: false)
    @repository = repository
    lockfile = Github::RepoFile.call(repository:, path: "Gemfile.lock")
    return { skipped: "no Gemfile.lock" } unless lockfile

    advisory_db_commit = Setting.current.advisory_db_commit
    if !force && unchanged?(lockfile, advisory_db_commit)
      repository.update_columns(last_scan: repository.last_scan.merge("checked_at" => Time.current))
      return { skipped: "lockfile unchanged" }
    end

    # The first recording of locked_versions counts as a change, so kept-current gems get checked.
    lockfile_changed = lockfile[:sha] != repository.lockfile_sha || repository.locked_versions.blank?
    ignore = ignored
    results = Lockfile::Audit.call(content: lockfile[:content], ignore:)
    summary = ActiveRecord::Base.transaction { record(results) }
    versions = Lockfile::Versions.new(lockfile[:content]).versions
    now = Time.current
    repository.update!(
      lockfile_sha: lockfile[:sha], runtimes: repository.with_runtime(:ruby, ruby_version), last_scanned_at: now,
      locked_versions: versions,
      last_scan: {
        checked_at: now, audited_at: now, lockfile_sha: lockfile[:sha], advisory_db_commit:,
        gems_checked: versions.size, advisories_checked: Advisory.where(ecosystem: "rubygems").count,
        ignored: ignore, **summary
      }
    )
    summary.merge(lockfile_changed:)
  end

  private

  def unchanged?(lockfile, advisory_db_commit)
    lockfile[:sha] == @repository.lockfile_sha && @repository.locked_versions.present? &&
      @repository.last_scan["advisory_db_commit"] == advisory_db_commit
  end

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
