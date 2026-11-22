require "rails_helper"

# Pure: lockfile fixtures and in-memory findings in, plain values out. No GitHub, no resolver.
RSpec.describe Fix::Analyze do
  around do |example|
    with_env("ADVISORY_DB_PATH" => AdvisoryDbHelpers::FIXTURE_DB.to_s) { example.run }
  end

  let(:repository) { create(:repository) }
  let(:rack) { create(:advisory, package_name: "rack", source_id: "CVE-2025-27610", cve: "CVE-2025-27610") }
  let(:session) { create(:advisory, package_name: "rack-session", source_id: "CVE-2025-46336", cve: "CVE-2025-46336") }
  let!(:rack_finding) { create(:finding, repository:, advisory: rack, locked_version: "3.1.0") }
  let!(:session_finding) { create(:finding, repository:, advisory: session, locked_version: "2.0.0") }

  def outcome(updated:, default: "rack_vulnerable", original: default, behind: {}, pull_request: nil)
    updated_lockfile = fixture_lockfile(updated)
    described_class.call(
      candidates: [rack_finding, session_finding], findings: repository.findings.includes(:advisory).to_a,
      still_flagged: Lockfile::Audit.call(content: updated_lockfile, ignore: []),
      default_lockfile: fixture_lockfile(default), original: fixture_lockfile(original), updated: updated_lockfile,
      behind:, pull_request:
    )
  end

  context "when everything resolved" do
    subject(:result) { outcome(updated: "rack_patched") }

    it "fixes every candidate, gem by gem" do
      expect(result.fixed).to contain_exactly(rack_finding, session_finding)
      expect(result.blocked).to be_empty
      expect(result.fixed_gems.map { [it.name, it.from, it.to] }).to eq([%w[rack 3.1.0 3.1.24], %w[rack-session 2.0.0 2.1.2]])
    end

    it "has nothing left over as a companion" do
      expect(result.companion).to be_empty
    end

    it "is worth publishing" do
      expect(result).not_to be_empty(new_pr: true)
    end
  end

  context "when one advisory is still flagged" do
    subject(:result) { outcome(updated: "rack_patch_only") }

    it "blocks it with a reason a human can act on" do
      expect(result.fixed).to eq([rack_finding])
      expect(result.blocked.map(&:finding)).to eq([session_finding])
      expect(result.blocked.first.reason).to start_with("No patch or minor release clears it; the fix needs")
    end

    it "leaves a finding already flagged with the reason it has" do
      session_finding.update!(status: "needs_attention", reason: "PR #3 was closed without merging.")

      expect(result.blocked).to be_empty
    end
  end

  it "is empty when a new PR's lockfile didn't move" do
    expect(outcome(updated: "rack_vulnerable")).to be_empty(new_pr: true)
  end

  describe "kept-current gems" do
    subject(:result) do
      outcome(default: "tooling_patched", updated: "tooling_current", behind: { "brakeman" => "8.1.1" })
    end

    before { [rack_finding, session_finding].each { it.update!(status: "resolved") } }

    it "reports the bump from the default branch's version" do
      expect(result.kept.sole).to have_attributes(name: "brakeman", from: "7.0.0", to: "8.1.1", latest: "8.1.1", note: nil)
      expect(result.bumps.map(&:name)).to eq(["brakeman"])
    end

    it "explains a gem held short of latest" do
      held = outcome(default: "tooling_patched", updated: "tooling_patched", behind: { "brakeman" => "8.1.1" })

      expect(held.kept.first).to have_attributes(to: "7.0.0", note: "Its dependencies or the repo's Ruby hold it back.")
      expect(held.bumps).to be_empty
    end
  end

  describe "the update message" do
    let(:pull_request) { create(:fix_pull_request, repository:, number: 7) }

    it "is nil for a new PR (its first commit carries the PR title)" do
      expect(outcome(updated: "rack_patched").update_message).to be_nil
    end

    it "names only what's new to an open PR" do
      rack_finding.update!(status: "in_pr", fix_pull_request: pull_request)
      result = outcome(updated: "rack_patched", original: "rack_patch_only", pull_request:)

      expect(result.update_message).to eq("Update: patch CVE-2025-46336 in rack-session")
    end
  end
end
