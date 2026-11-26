require "rails_helper"

RSpec.describe RepositoryScan do
  let(:repository) { create(:repository, lockfile_sha: nil) }
  let!(:rack_advisory) { create(:advisory, package_name: "rack", source_id: "CVE-2025-27610", cve: "CVE-2025-27610") }
  let!(:session_advisory) do
    create(:advisory, package_name: "rack-session", source_id: "CVE-2025-46336", cve: "CVE-2025-46336")
  end
  let(:files) do
    {
      "Gemfile.lock" => { sha: "sha-1", content: fixture_lockfile("rack_vulnerable") },
      ".ruby-version" => { sha: "rv", content: "3.4.9\n" }
    }
  end

  around do |example|
    with_env("ADVISORY_DB_PATH" => AdvisoryDbHelpers::FIXTURE_DB.to_s) { example.run }
  end

  before do
    allow(Github::RepoFile).to receive(:call) { |repository:, path:| files[path] }
  end

  it "opens a finding with a detected event for each vulnerable gem" do
    result = described_class.call(repository:)

    expect(result).to eq(detected: 2, resolved: 0, open: 2, lockfile_changed: true)
    rack = repository.findings.find_by(advisory: rack_advisory)
    expect(rack).to have_attributes(status: "open", locked_version: "3.1.0")
    expect(rack.events.pluck(:kind)).to eq(["detected"])
  end

  it "records the lockfile sha, Ruby version and scan time" do
    described_class.call(repository:)

    expect(repository.reload).to have_attributes(lockfile_sha: "sha-1", runtimes: { "ruby" => "3.4.9" }, last_scanned_at: be_present)
  end

  it "records the locked versions" do
    described_class.call(repository:)

    expect(repository.reload.locked_versions).to eq("rack" => "3.1.0", "rack-session" => "2.0.0")
  end

  it "scans an unchanged lockfile once to record its versions, as a change" do
    repository.update!(lockfile_sha: "sha-1", locked_versions: {})

    expect(described_class.call(repository:)).to include(lockfile_changed: true)
    expect(repository.reload.locked_versions).to be_present
  end

  it "skips an unchanged lockfile unless forced" do
    described_class.call(repository:)

    expect(described_class.call(repository: repository.reload)).to eq(skipped: "lockfile unchanged")
    expect(described_class.call(repository:, force: true)).to eq(detected: 0, resolved: 0, open: 2, lockfile_changed: false)
  end

  it "records what the scan checked" do
    Setting.current.update_columns(advisory_db_commit: "db-1")
    files["config/bundler-audit.yml"] = { sha: "c", content: "ignore:\n  - CVE-2099-0001\n" }

    described_class.call(repository:)

    scan = repository.reload.last_scan
    expect(scan).to include(
      "lockfile_sha" => "sha-1", "advisory_db_commit" => "db-1", "gems_checked" => 2, "advisories_checked" => 2,
      "ignored" => ["CVE-2099-0001"], "detected" => 2, "resolved" => 0, "open" => 2
    )
    expect(scan["checked_at"]).to eq(scan["audited_at"])
  end

  it "moves only checked_at on a skipped scan" do
    described_class.call(repository:)
    audited = repository.reload.last_scan

    travel 5.minutes do
      described_class.call(repository:)
    end

    scan = repository.reload.last_scan
    expect(scan.except("checked_at")).to eq(audited.except("checked_at"))
    expect(Time.zone.parse(scan["checked_at"])).to be > Time.zone.parse(audited["checked_at"])
  end

  it "audits an unchanged lockfile once the advisory db has moved" do
    Setting.current.update_columns(advisory_db_commit: "db-1")
    described_class.call(repository:)
    Setting.current.update_columns(advisory_db_commit: "db-2")

    expect(described_class.call(repository: repository.reload)).to include(open: 2, lockfile_changed: false)
    expect(repository.reload.last_scan["advisory_db_commit"]).to eq("db-2")
  end

  it "doesn't duplicate findings or events on a re-scan" do
    described_class.call(repository:)
    described_class.call(repository:, force: true)

    expect(repository.findings.count).to eq(2)
    expect(FindingEvent.where(kind: "detected").count).to eq(2)
  end

  it "resolves findings once the lockfile is patched" do
    described_class.call(repository:)
    files["Gemfile.lock"] = { sha: "sha-2", content: fixture_lockfile("rack_patched") }

    result = described_class.call(repository: repository.reload)

    expect(result).to eq(detected: 0, resolved: 2, open: 0, lockfile_changed: true)
    expect(repository.findings.pluck(:status).uniq).to eq(["resolved"])
    expect(FindingEvent.where(kind: "resolved").count).to eq(2)
  end

  it "re-opens a finding if the vulnerable version comes back" do
    described_class.call(repository:)
    files["Gemfile.lock"] = { sha: "sha-2", content: fixture_lockfile("rack_patched") }
    described_class.call(repository: repository.reload)
    files["Gemfile.lock"] = { sha: "sha-3", content: fixture_lockfile("rack_vulnerable") }

    described_class.call(repository: repository.reload)

    rack = repository.findings.find_by(advisory: rack_advisory)
    expect(rack.status).to eq("open")
    expect(rack.events.pluck(:kind)).to eq(%w[detected resolved detected])
  end

  it "honors the repo's bundler-audit ignore list" do
    files["config/bundler-audit.yml"] = { sha: "c", content: "ignore:\n  - CVE-2025-46336\n" }

    described_class.call(repository:)

    expect(repository.findings.map(&:advisory)).to eq([rack_advisory])
  end

  it "skips a repo without a Gemfile.lock" do
    files.delete("Gemfile.lock")

    expect(described_class.call(repository:)).to eq(skipped: "no Gemfile.lock")
  end
end
