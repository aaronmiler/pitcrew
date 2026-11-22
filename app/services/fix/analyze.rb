module Fix
  # Works out what a resolve achieved: the findings it fixed, the ones it couldn't (and why),
  # the kept-current gems it moved, and what moved along with them. No IO: everything comes
  # in as arguments, so it's testable with lockfile fixtures alone. Returns a Fix::Outcome.
  #   candidates:       findings this run may put in the PR
  #   findings:         the repo's findings, to match still-flagged advisories against
  #   still_flagged:    audit results for the updated lockfile
  #   default_lockfile: the default branch's (the PR is described against it)
  #   original:         the checkout's before resolving (the PR branch's, for an update)
  #   updated:          after resolving
  #   behind:           { gem => latest } kept-current gems behind on the default branch
  #   pull_request:     the open PR being updated, if any (for its commit message)
  class Analyze < ApplicationService
    def call(candidates:, findings:, still_flagged:, default_lockfile:, original:, updated:, behind:, pull_request: nil)
      @default_lockfile = default_lockfile
      @original = original
      @updated = updated
      blocked = build_blocked(still_flagged, findings)
      fixed = candidates.reject { |finding| blocked.any? { it.finding == finding } }
      kept = build_kept(behind)
      fixed_gems = group(fixed)

      Outcome.new(
        fixed:, blocked:, kept:, fixed_gems:,
        companion: companion(fixed_gems, kept),
        lockfile_changed: updated != original,
        update_message: (update_message(fixed, kept, pull_request) if pull_request)
      )
    end

    private

    # What an update adds, judged against the branch's own lockfile, not the DB: people can
    # push to the branch (a rollback can undo a bump Pitcrew recorded).
    def update_message(fixed, kept, pull_request)
      added = fixed.reject { it.in_pr? && it.fix_pull_request_id == pull_request.id }
      branch = Lockfile::Versions.new(@original).versions
      new_bumps = kept.select(&:bumped?).filter_map do |gem|
        Lockfile::Change.new(name: gem.name, from: branch[gem.name], to: gem.to) if branch[gem.name] != gem.to
      end
      PullRequestContent.update_message(added: group(added), bumps: new_bumps)
    end

    # Gems that moved without advisories or a keep-current entry of their own: lockstep
    # families (Rails) and dependencies the update pulled along.
    def companion(fixed_gems, kept)
      shown = fixed_gems.map(&:name) + kept.map(&:name)
      Lockfile::Versions.changes(@default_lockfile, @updated).reject { shown.include?(it.name) }
    end

    def updated_versions
      @updated_versions ||= Lockfile::Versions.new(@updated)
    end

    # Fix::FixedGem per gem, from the version the findings saw to the updated lockfile's.
    def group(findings)
      findings.group_by { it.advisory.package_name }.sort.map do |name, gem_findings|
        FixedGem.new(
          name:, from: gem_findings.first.locked_version, to: updated_versions.versions[name] || "removed",
          advisories: gem_findings.map(&:advisory)
        )
      end
    end

    def build_blocked(still_flagged, findings)
      by_advisory = findings.index_by { [it.advisory.package_name, it.advisory.source_id] }
      still_flagged.uniq { [it.gem.name, it.advisory.id] }.filter_map do |result|
        finding = by_advisory[[result.gem.name, result.advisory.id]]
        next if finding.nil? || finding.needs_attention? # keep the reason it already has

        Blocked.new(finding:, reason: blocked_reason(result))
      end
    end

    def blocked_reason(result)
      needed = result.advisory.patched_versions.map(&:to_s).join(" or ").presence || "no patched release yet"
      requirement = updated_versions.gemfile_requirement(result.gem.name)
      if requirement
        "The Gemfile requires #{result.gem.name} #{requirement}; the fix needs #{needed}."
      else
        "No patch or minor release clears it; the fix needs #{needed}."
      end
    end

    def build_kept(behind)
      before = Lockfile::Versions.new(@default_lockfile).versions
      behind.filter_map do |name, latest|
        from, to = before[name], updated_versions.versions[name]
        next unless from && to

        KeptGem.new(name:, from:, to:, latest:, note: short_of_latest_note(name, to, latest))
      end.sort_by(&:name)
    end

    def short_of_latest_note(name, to, latest)
      return if Gem::Version.new(to) >= Gem::Version.new(latest)

      requirement = updated_versions.gemfile_requirement(name)
      requirement ? "The Gemfile requires #{name} #{requirement}." : "Its dependencies or the repo's Ruby hold it back."
    end
  end
end
