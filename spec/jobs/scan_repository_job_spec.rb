require "rails_helper"

RSpec.describe ScanRepositoryJob, type: :job do
  include ActiveJob::TestHelper

  before { allow(AdvisoryDb).to receive(:cloned?).and_return(true) }

  it "scans an enabled repo" do
    repository = create(:repository, enabled: true)
    allow(RepositoryScan).to receive(:call).and_return(detected: 0, resolved: 0, open: 0)

    described_class.perform_now(repository.id, force: true)

    expect(RepositoryScan).to have_received(:call).with(repository:, force: true)
  end

  it "ignores a disabled or missing repo" do
    allow(RepositoryScan).to receive(:call)

    described_class.perform_now(create(:repository, enabled: false).id)
    described_class.perform_now(0)

    expect(RepositoryScan).not_to have_received(:call)
  end

  it "skips when the advisory db hasn't been cloned yet" do
    allow(AdvisoryDb).to receive(:cloned?).and_return(false)
    allow(RepositoryScan).to receive(:call)

    described_class.perform_now(create(:repository, enabled: true).id)

    expect(RepositoryScan).not_to have_received(:call)
  end

  describe "queuing a fix" do
    let(:repository) { create(:repository, enabled: true) }

    def scan_returning(result)
      allow(RepositoryScan).to receive(:call).and_return(result)
      described_class.perform_now(repository.id)
    end

    it "queues a fix when there are open findings" do
      create(:finding, repository:, status: "open")

      scan_returning(detected: 1, resolved: 0, open: 1, lockfile_changed: true)

      expect(FixRepositoryJob).to have_been_enqueued.with(repository.id, force: false)
    end

    it "refreshes an open PR (forced) when the default branch's lockfile changed" do
      create(:fix_pull_request, repository:)

      scan_returning(detected: 0, resolved: 0, open: 0, lockfile_changed: true)

      expect(FixRepositoryJob).to have_been_enqueued.with(repository.id, force: true)
    end

    it "checks an open PR when findings resolved, without forcing a merge" do
      create(:fix_pull_request, repository:)

      scan_returning(detected: 0, resolved: 1, open: 0, lockfile_changed: false)

      expect(FixRepositoryJob).to have_been_enqueued.with(repository.id, force: false)
    end

    it "queues a fix when a changed lockfile leaves a kept-current gem behind" do
      Setting.current.update!(keep_current_gems: ["brakeman"])
      GemRelease.create!(name: "brakeman", version: "8.1.1", checked_at: Time.current)
      repository.update!(locked_versions: { "brakeman" => "7.0.0" })

      scan_returning(detected: 0, resolved: 0, open: 0, lockfile_changed: true)

      expect(FixRepositoryJob).to have_been_enqueued.with(repository.id, force: false)
    end

    it "does nothing when the scan was skipped or there's nothing to do" do
      scan_returning(skipped: "lockfile unchanged")
      scan_returning(detected: 0, resolved: 0, open: 0, lockfile_changed: true)

      expect(FixRepositoryJob).not_to have_been_enqueued
    end
  end

  describe "failures" do
    let(:repository) { create(:repository, enabled: true) }

    it "records the error on the repo and re-raises it for GoodJob" do
      allow(RepositoryScan).to receive(:call).and_raise(OpenSSL::PKey::RSAError, "bad key")

      expect { described_class.perform_now(repository.id) }.to raise_error(OpenSSL::PKey::RSAError)
      expect(repository.reload).to have_attributes(last_error: "OpenSSL::PKey::RSAError: bad key", last_error_source: "scan")
    end

    it "clears its own error after a successful scan" do
      repository.record_error!("scan", RuntimeError.new("old"))
      allow(RepositoryScan).to receive(:call).and_return(skipped: "lockfile unchanged")

      described_class.perform_now(repository.id)

      expect(repository.reload.last_error).to be_nil
    end
  end
end
