module AdvisoryDb
  # Indexes ruby-advisory-db's gem advisories into `advisories`: every file on the first
  # run (before: nil), otherwise only files added or changed between two commits.
  # Ruby interpreter advisories (rubies/) are skipped; they aren't lockfile issues.
  # Returns the ids of advisories created by this run.
  class Import < ApplicationService
    def call(path: AdvisoryDb.path, before: nil, after: nil)
      @path = path
      files = changed_files(before, after)
      return [] if files.empty?

      @added_at = first_commit_times
      files.filter_map { |relative| import(relative) }
    end

    private

    def changed_files(before, after)
      return Dir.glob("gems/*/*.yml", base: @path).sort if before.nil?
      return [] if before == after

      Command.run!("git", "diff", "--name-only", "--diff-filter=AMR", before, after, "--", "gems/", chdir: @path)
        .lines(chomp: true).grep(%r{\Agems/[^/]+/[^/]+\.yml\z})
    end

    # When each advisory file was added, in one pass over history (not one git call per file).
    def first_commit_times
      log = Command.run!("git", "log", "--diff-filter=A", "--format=%x00%cI", "--name-only", "--", "gems/", chdir: @path)
      log.split("\0").each_with_object({}) do |entry, times|
        timestamp, *files = entry.strip.lines(chomp: true).reject(&:empty?)
        files.each { |file| times[file] ||= Time.iso8601(timestamp) } if timestamp
      end
    end

    # Returns the advisory's id if this run created it.
    def import(relative)
      parsed = Bundler::Audit::Advisory.load(@path.join(relative).to_s)
      record = Advisory.find_or_initialize_by(
        ecosystem: "rubygems", package_name: relative.split("/")[1], source_id: parsed.id
      )
      created = record.new_record?

      record.assign_attributes(
        cve: prefixed("CVE", parsed.cve),
        ghsa: prefixed("GHSA", parsed.ghsa),
        title: parsed.title,
        url: parsed.url,
        criticality: parsed.criticality&.to_s,
        patched_versions: parsed.patched_versions.map(&:to_s),
        unaffected_versions: parsed.unaffected_versions.map(&:to_s),
        published_on: parsed.date,
        source_committed_at: @added_at[relative] || record.source_committed_at
      )
      record.first_seen_at ||= Time.current
      record.save!
      record.id if created
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("[AdvisoryDb::Import] skipped #{relative}: #{e.message}")
      nil
    end

    def prefixed(prefix, value)
      return if value.blank?

      value.to_s.start_with?("#{prefix}-") ? value.to_s : "#{prefix}-#{value}"
    end
  end
end
