module Reports
  # Value reporting for /reports, built on finding_events. CVEs only: kept-current bumps
  # (GemBump) are left out. Durations are seconds, nil when there's nothing to measure.
  #
  # range: "30d" | "90d" | "all". `previous` is the same-length period before it (nil for
  # "all"), for deltas. `trend` is always the last TREND_WEEKS weeks, for sparklines.
  class Summary < ApplicationService
    RANGES = { "30d" => 30.days, "90d" => 90.days, "all" => nil }.freeze
    TREND_WEEKS = 12

    def call(range: "30d", now: Time.current)
      length = RANGES.fetch(range)
      window = (length && (now - length))..now
      setting = Setting.current
      @minutes = [setting.manual_fix_minutes_low, setting.manual_fix_minutes_high]

      rows = event_rows(window)
      fixes = fixes(window)
      {
        range:,
        since: window.begin,
        until: now,
        repos_covered: Repository.enabled.count,
        totals: totals(rows, fixes),
        previous: length && previous_totals((now - (2 * length))...(now - length)),
        exposure: exposure(fixes),
        head_start: head_start(window),
        trend: trend(now),
        repos: repos(rows, fixes)
      }
    end

    private

    # The events that count as outcomes, flattened so periods can be bucketed in Ruby.
    def event_rows(window)
      FindingEvent.where(occurred_at: window, kind: %w[merged needs_attention resolved]).joins(:finding)
        .pluck(:kind, :finding_id, :occurred_at, "findings.repository_id", Arel.sql("finding_events.metadata->>'pr'"))
        .map { |kind, finding_id, at, repository_id, pr| { kind:, finding_id:, at:, repository_id:, pr: } }
    end

    # One entry per finding merged in a Pitcrew PR during the window, with its stage timings.
    # The stages run from the latest detection before the merge (a finding can come back).
    # published → detected only counts advisories published after Pitcrew started watching
    # the repo; older ones were a backlog found on the first scan, not a detection speed.
    def fixes(window)
      FindingEvent.merged.where(occurred_at: window).includes(finding: %i[advisory repository events]).filter_map do |merge|
        finding = merge.finding
        history = finding.events.select { it.occurred_at <= merge.occurred_at }
        detected = history.reverse.find(&:detected?)
        next unless detected

        pr = history.find { (it.pr_opened? || it.pr_updated?) && it.occurred_at >= detected.occurred_at }
        published_on = finding.advisory.published_on
        published = published_on.in_time_zone if published_on && published_on > finding.repository.created_at.to_date
        {
          repository_id: finding.repository_id,
          merged_at: merge.occurred_at,
          published_to_detected: published && seconds(published, detected.occurred_at),
          published_to_merged: published && seconds(published, merge.occurred_at),
          detected_to_pr: pr && seconds(detected.occurred_at, pr.occurred_at),
          pr_to_merged: pr && seconds(pr.occurred_at, merge.occurred_at),
          detected_to_merged: seconds(detected.occurred_at, merge.occurred_at)
        }
      end
    end

    # A finding merged in the period was auto-fixed; one flagged and not merged in the same
    # period needed a person.
    def totals(rows, fixes)
      auto = rows.select { it[:kind] == "merged" }.map { it[:finding_id] }.uniq
      flagged = rows.select { it[:kind] == "needs_attention" }.map { it[:finding_id] }.uniq - auto
      outcomes = auto.size + flagged.size
      {
        closed: rows.count { it[:kind] == "resolved" },
        auto_fixed: auto.size,
        needs_attention: flagged.size,
        auto_fix_rate: outcomes.zero? ? nil : (auto.size.to_f / outcomes).round(3),
        prs_merged: rows.select { it[:kind] == "merged" }.map { [it[:repository_id], it[:pr]] }.uniq.size,
        detected_to_merged: median(fixes.filter_map { it[:detected_to_merged] }),
        minutes_saved: @minutes.map { auto.size * it }
      }
    end

    def previous_totals(window)
      totals(event_rows(window), fixes(window))
    end

    def exposure(fixes)
      %i[published_to_detected detected_to_pr pr_to_merged detected_to_merged published_to_merged].index_with do |stage|
        values = fixes.filter_map { it[stage] }
        { median: median(values), count: values.size }
      end
    end

    # How long after ruby-advisory-db had an advisory GitHub reviewed it (when Dependabot
    # would have known). Negative when GitHub was first; shown as is. Only advisories new
    # since the first import have GitHub dates.
    def head_start(window)
      leads = Advisory.where(source_committed_at: window).where.not(ghsa_reviewed_at: nil)
        .pluck(:source_committed_at, :ghsa_reviewed_at).map { |ours, github| seconds(ours, github) }
      { median: median(leads), count: leads.size, ahead: leads.count(&:positive?), behind: leads.count(&:negative?) }
    end

    # Weekly totals (weeks start Monday), oldest first.
    def trend(now)
      first = now.beginning_of_week - (TREND_WEEKS - 1).weeks
      rows = event_rows(first..now)
      fixes = fixes(first..now)
      Array.new(TREND_WEEKS) do |index|
        week = (first + index.weeks)...(first + (index + 1).weeks)
        totals(rows.select { week.cover?(it[:at]) }, fixes.select { week.cover?(it[:merged_at]) })
          .slice(:closed, :auto_fixed, :needs_attention, :auto_fix_rate, :detected_to_merged)
          .merge(week_start: week.begin.to_date)
      end
    end

    # Enabled repos plus any with activity in the window; busiest first.
    def repos(rows, fixes)
      open = Finding.where.not(status: "resolved").group(:repository_id).count
      ids = Repository.enabled.pluck(:id) | rows.map { it[:repository_id] }
      Repository.where(id: ids).map do |repo|
        totals(rows.select { it[:repository_id] == repo.id }, fixes.select { it[:repository_id] == repo.id })
          .slice(:closed, :auto_fixed, :needs_attention, :detected_to_merged)
          .merge(id: repo.id, full_name: repo.full_name, open_now: open.fetch(repo.id, 0))
      end.sort_by { [-it[:closed], -it[:open_now], it[:full_name]] }
    end

    def seconds(from, to)
      (to - from).round
    end

    def median(values)
      return if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    end
  end
end
