require "rails_helper"

RSpec.describe GemReleasesJob, type: :job do
  include ActiveJob::TestHelper

  before { Setting.current.update!(keep_current_gems: ["brakeman"]) }

  it "refreshes enabled repos that a new release leaves behind" do
    behind = create(:repository, locked_versions: { "brakeman" => "7.0.0" })
    create(:repository, locked_versions: { "brakeman" => "8.1.1" })
    create(:repository, enabled: false, locked_versions: { "brakeman" => "7.0.0" })
    allow(GemReleaseSync).to receive(:call) do
      GemRelease.create!(name: "brakeman", version: "8.1.1", checked_at: Time.current)
      ["brakeman"]
    end

    described_class.perform_now

    expect(FixRepositoryJob).to have_been_enqueued.exactly(:once).with(behind.id, force: true)
  end

  it "does nothing without a new release" do
    create(:repository, locked_versions: { "brakeman" => "7.0.0" })
    allow(GemReleaseSync).to receive(:call).and_return([])

    described_class.perform_now

    expect(FixRepositoryJob).not_to have_been_enqueued
  end
end
