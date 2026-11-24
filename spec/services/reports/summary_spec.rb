require "rails_helper"

RSpec.describe Reports::Summary do
  let(:now) { Time.zone.parse("2026-11-20 12:00") }
  let(:repo) { create(:repository, created_at: now - 60.days) }

  def event(finding, kind, at, **metadata)
    create(:finding_event, finding:, kind:, occurred_at: at, metadata:)
  end

  # Detected, put in PR #1, merged and resolved: an auto-fix.
  def auto_fix(detected:, pr:, merged:, published_on: nil, repository: repo)
    finding = create(:finding, repository:, advisory: create(:advisory, published_on:), status: "resolved")
    event(finding, :detected, detected)
    event(finding, :pr_opened, pr, pr: 1)
    event(finding, :merged, merged, pr: 1)
    event(finding, :resolved, merged + 1.hour)
    finding
  end

  def flagged(at)
    finding = create(:finding, repository: repo, status: "needs_attention")
    event(finding, :detected, at - 1.hour)
    event(finding, :needs_attention, at, reason: "Gemfile")
    finding
  end

  it "totals auto-fixes, flags, merged PRs and time saved for the range" do
    auto_fix(detected: now - 3.days, pr: now - 3.days + 1.hour, merged: now - 2.days)
    auto_fix(detected: now - 3.days, pr: now - 3.days + 1.hour, merged: now - 2.days)
    flagged(now - 1.day)
    create(:setting, manual_fix_minutes_low: 10, manual_fix_minutes_high: 20)

    totals = described_class.call(range: "30d", now:)[:totals]

    expect(totals).to include(
      closed: 2, auto_fixed: 2, needs_attention: 1, auto_fix_rate: 0.667, prs_merged: 1,
      detected_to_merged: 1.day.to_i, minutes_saved: [20, 40]
    )
  end

  it "leaves out events outside the range and compares the previous period" do
    auto_fix(detected: now - 40.days, pr: now - 40.days, merged: now - 39.days)

    report = described_class.call(range: "30d", now:)

    expect(report[:totals]).to include(auto_fixed: 0, auto_fix_rate: nil, detected_to_merged: nil)
    expect(report[:previous]).to include(auto_fixed: 1)
  end

  it "has no previous period for all time" do
    expect(described_class.call(range: "all", now:)[:previous]).to be_nil
  end

  it "doesn't count a finding flagged then merged in the same period as needing a person" do
    finding = auto_fix(detected: now - 3.days, pr: now - 2.days, merged: now - 1.day)
    event(finding, :needs_attention, now - 2.days - 1.hour, reason: "conflict")

    expect(described_class.call(range: "30d", now:)[:totals]).to include(auto_fixed: 1, needs_attention: 0)
  end

  describe "exposure" do
    it "times each stage from the latest detection before the merge" do
      finding = auto_fix(detected: now - 10.days, pr: now - 10.days + 2.hours, merged: now - 9.days)
      event(finding, :detected, now - 5.days)
      event(finding, :pr_updated, now - 5.days + 1.hour, pr: 2)
      event(finding, :merged, now - 4.days, pr: 2)

      exposure = described_class.call(range: "30d", now:)[:exposure]

      expect(exposure[:detected_to_pr]).to eq(median: 90.minutes.to_i, count: 2)
      expect(exposure[:pr_to_merged]).to eq(median: 22.5.hours.to_i, count: 2)
    end

    it "counts published → detected only for advisories published after the repo was added" do
      auto_fix(published_on: (now - 5.days).to_date, detected: now - 4.days, pr: now - 4.days, merged: now - 3.days)
      auto_fix(published_on: (now - 2.years).to_date, detected: now - 4.days, pr: now - 4.days, merged: now - 3.days)

      exposure = described_class.call(range: "30d", now:)[:exposure]

      published = (now - 5.days).to_date.in_time_zone
      expect(exposure[:published_to_detected]).to eq(median: (now - 4.days - published).round, count: 1)
      expect(exposure[:detected_to_merged][:count]).to eq(2)
    end
  end

  it "reports GitHub's lag behind ruby-advisory-db, negative when GitHub was first" do
    create(:advisory, source_committed_at: now - 10.days, ghsa_reviewed_at: now - 7.days)
    create(:advisory, source_committed_at: now - 10.days, ghsa_reviewed_at: now - 11.days)
    create(:advisory, source_committed_at: now - 10.days, ghsa_reviewed_at: nil)

    head_start = described_class.call(range: "30d", now:)[:head_start]

    expect(head_start).to eq(median: 1.day.to_i, count: 2, ahead: 1, behind: 1)
  end

  it "buckets the last 12 weeks for sparklines, oldest first" do
    auto_fix(detected: now - 3.days, pr: now - 3.days, merged: now - 2.days)

    trend = described_class.call(range: "30d", now:)[:trend]

    expect(trend.size).to eq(12)
    expect(trend.last).to include(week_start: now.beginning_of_week.to_date, auto_fixed: 1, closed: 1)
    expect(trend.first[:auto_fixed]).to eq(0)
  end

  it "lists enabled repos and active ones with their open findings, busiest first" do
    quiet = create(:repository, full_name: "aaronmiler/quiet")
    create(:finding, repository: quiet, status: "open")
    create(:repository, enabled: false, full_name: "aaronmiler/off")
    auto_fix(detected: now - 3.days, pr: now - 3.days, merged: now - 2.days)

    repos = described_class.call(range: "30d", now:)[:repos]

    expect(repos.map { it[:full_name] }).to eq([repo.full_name, "aaronmiler/quiet"])
    expect(repos.last).to include(open_now: 1, closed: 0)
  end
end
