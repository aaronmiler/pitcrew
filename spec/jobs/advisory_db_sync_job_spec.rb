require "rails_helper"

RSpec.describe AdvisoryDbSyncJob, type: :job do
  include ActiveJob::TestHelper

  let!(:enabled) { create(:repository, enabled: true) }

  before { create(:repository, enabled: false) }

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
