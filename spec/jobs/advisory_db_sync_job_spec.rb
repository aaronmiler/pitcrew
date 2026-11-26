require "rails_helper"

RSpec.describe AdvisoryDbSyncJob, type: :job do
  include ActiveJob::TestHelper

  let!(:enabled) { create(:repository, enabled: true) }

  before do
    create(:repository, enabled: false)
    allow(AdvisoryDb).to receive(:committed_at).and_return(Time.zone.parse("2026-11-22 14:40:03"))
  end

  it "records where the advisory db stands on every run, moved or not" do
    allow(AdvisoryDb::Sync).to receive(:call).and_return(before: "abc", after: "abc")

    freeze_time do
      described_class.perform_now

      expect(Setting.current).to have_attributes(
        advisory_db_commit: "abc", advisory_db_committed_at: Time.zone.parse("2026-11-22 14:40:03"),
        advisory_db_checked_at: Time.current
      )
    end
  end

  it "does nothing when the advisory db hasn't moved" do
    allow(AdvisoryDb::Sync).to receive(:call).and_return(before: "abc", after: "abc")
    allow(AdvisoryDb::Import).to receive(:call)

    described_class.perform_now

    expect(AdvisoryDb::Import).not_to have_received(:call)
    expect(ScanRepositoryJob).not_to have_been_enqueued
  end

  it "imports changes, fetches GitHub dates for new advisories, and rescans enabled repos" do
    allow(AdvisoryDb::Sync).to receive(:call).and_return(before: "abc", after: "def")
    allow(AdvisoryDb::Import).to receive(:call).with(before: "abc", after: "def").and_return([11, 12])

    described_class.perform_now

    expect(AdvisoryDatesJob).to have_been_enqueued.with(11)
    expect(AdvisoryDatesJob).to have_been_enqueued.with(12)
    expect(ScanRepositoryJob).to have_been_enqueued.with(enabled.id, force: true).exactly(:once)
  end

  it "skips GitHub dates on the first (historical) import" do
    allow(AdvisoryDb::Sync).to receive(:call).and_return(before: nil, after: "def")
    allow(AdvisoryDb::Import).to receive(:call).and_return([11])

    described_class.perform_now

    expect(AdvisoryDatesJob).not_to have_been_enqueued
    expect(ScanRepositoryJob).to have_been_enqueued.with(enabled.id, force: true)
  end
end
