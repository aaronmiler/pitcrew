require "rails_helper"

RSpec.describe PullRequestContent do
  let(:repository) { build(:repository, full_name: "aaronmiler/app") }
  let(:rack) { build(:advisory, package_name: "rack", cve: "CVE-2025-1", url: "https://example.com/1") }
  let(:rack_two) { build(:advisory, package_name: "rack", cve: "CVE-2025-2", url: nil) }
  let(:proxy) { build(:advisory, package_name: "rack-proxy", cve: "CVE-2025-3") }
  let(:blocked_finding) { build(:finding, advisory: proxy, locked_version: "0.8.3") }

  def fixed(name, from, to, advisories)
    Fix::FixedGem.new(name:, from:, to:, advisories:)
  end

  def change(name, from, to)
    Lockfile::Change.new(name:, from:, to:)
  end

  def kept(name, from, to, latest, note = nil)
    Fix::KeptGem.new(name:, from:, to:, latest:, note:)
  end

  let(:content) do
    described_class.new(
      repository:,
      fixed: [fixed("rack", "3.1.0", "3.1.24", [rack, rack_two])],
      companion: [change("actionview", "8.1.3", "8.1.4.1")],
      blocked: [Fix::Blocked.new(finding: blocked_finding, reason: "The Gemfile requires rack-proxy ~> 0.8; the fix needs >= 1.0.3.")]
    )
  end

  it "renders the title from the setting" do
    expect(content.title).to eq("chore(security): patch 2 advisories in rack")
  end

  it "offers a pluralized gem count" do
    Setting.current.update!(pr_title_template: "chore(security): patch %{advisories} in %{gem_count}")

    expect(content.title).to eq("chore(security): patch 2 advisories in 1 gem")
  end

  it "truncates long lists in the title" do
    Setting.current.update!(pr_title_template: "fix %{gems}")
    many = %w[a b c d e].map { |gem| fixed(gem, "1", "2", [build(:advisory, package_name: gem)]) }

    title = described_class.new(repository:, fixed: many, companion: [], blocked: []).title

    expect(title).to eq("fix a, b, c +2 more")
  end

  it "lists fixes, lockstep companions and what needs a human" do
    body = content.body

    expect(body).to include("| `rack` | 3.1.0 | 3.1.24 | [CVE-2025-1](https://example.com/1), CVE-2025-2 |")
    expect(body).to include("`actionview` 8.1.3 → 8.1.4.1")
    expect(body).to include("### Needs a manual look")
    expect(body).to include("**`rack-proxy`** 0.8.3: [CVE-2025-3](https://example.com/advisory). " \
                            "The Gemfile requires rack-proxy ~> 0.8")
  end

  describe "kept-current gems" do
    let(:bumped) { kept("brakeman", "7.0.0", "8.1.1", "8.1.1") }

    it "uses the tooling title when the PR fixes no advisory" do
      content = described_class.new(repository:, fixed: [], companion: [], blocked: [], kept_current: [bumped])

      expect(content.title).to eq("chore(deps): update brakeman")
      expect(content.body).to start_with("Pitcrew updated `brakeman` to the latest release")
      expect(content.body).to include("### Kept current").and include("| `brakeman` | 7.0.0 | 8.1.1 | 8.1.1 |")
      expect(content.body).not_to include("| Advisories |")
    end

    it "keeps the security title when the PR also fixes advisories" do
      content = described_class.new(
        repository:, fixed: [fixed("rack", "3.1.0", "3.1.24", [rack])], companion: [], blocked: [], kept_current: [bumped]
      )

      expect(content.title).to eq("chore(security): patch 1 advisory in rack")
      expect(content.body).to include("| `brakeman` | 7.0.0 | 8.1.1 | 8.1.1 |")
    end

    it "explains a gem held short of its latest release" do
      held = kept("brakeman", "7.0.0", "7.0.0", "8.1.1", "The Gemfile requires brakeman ~> 7.0.")
      content = described_class.new(
        repository:, fixed: [fixed("rack", "3.1.0", "3.1.24", [rack])], companion: [], blocked: [], kept_current: [held]
      )

      expect(content.body).to include("- `brakeman` 7.0.0 is short of the latest, 8.1.1. The Gemfile requires brakeman ~> 7.0.")
      expect(content.body).not_to include("| Latest |")
    end
  end

  describe ".update_message" do
    it "says what an update adds" do
      message = described_class.update_message(added: [fixed("rack", nil, nil, [rack, rack_two])], bumps: [change("brakeman", "8.1.0", "8.1.1")])

      expect(message).to eq("Update: patch CVE-2025-1, CVE-2025-2 in rack; brakeman 8.1.0 → 8.1.1")
    end

    it "counts advisories when a gem has many" do
      message = described_class.update_message(added: [fixed("rack", nil, nil, [rack, rack_two, proxy])], bumps: [])

      expect(message).to eq("Update: patch 3 advisories in rack")
    end

    it "truncates a long list" do
      bumps = %w[a b c d e].map { change(it, "1", "2") }

      expect(described_class.update_message(added: [], bumps:)).to eq("Update: a 1 → 2; b 1 → 2; c 1 → 2 +2 more")
    end

    it "falls back to a plain message when nothing new arrived" do
      expect(described_class.update_message(added: [], bumps: [])).to eq("Update Gemfile.lock")
    end
  end
end
