require "rails_helper"

RSpec.describe Setting, type: :model do
  describe ".current" do
    it "creates the row with defaults on first use" do
      expect(described_class.current.pr_title_template)
        .to eq("chore(security): patch %{advisories} in %{gems}")
    end

    it "returns the same row every time" do
      expect(described_class.current).to eq(described_class.current)
      expect(described_class.count).to eq(1)
    end
  end

  it "allows only one row, enforced by the database" do
    create(:setting)

    expect { create(:setting) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "pr_title_template" do
    it "accepts the documented fields" do
      expect(build(:setting, pr_title_template: "[%{repo}] %{count} fixes: %{ids} (%{date})")).to be_valid
    end

    it "rejects an unknown field and names it" do
      setting = build(:setting, pr_title_template: "patch %{nope}")

      expect(setting).not_to be_valid
      expect(setting.errors[:pr_title_template].first).to include("nope")
    end

    it "is required" do
      expect(build(:setting, pr_title_template: "")).not_to be_valid
    end
  end

  describe "allowed_orgs" do
    it "defaults to none" do
      expect(described_class.current.allowed_orgs).to eq([])
    end

    it "is normalized to unique, lowercase, non-blank org names" do
      setting = create(:setting, allowed_orgs: [" RunOnRoh ", "runonroh", "", "aaronmiler"])

      expect(setting.reload.allowed_orgs).to eq(%w[runonroh aaronmiler])
    end
  end

  describe "#render_pr_title" do
    it "fills in the fields" do
      setting = build(:setting, pr_title_template: "[%{repo}] patch %{advisories} in %{gems}")

      expect(setting.render_pr_title(repo: "aaronmiler/app", advisories: "2 advisories", gems: "rack"))
        .to eq("[aaronmiler/app] patch 2 advisories in rack")
    end

    it "treats any other % literally" do
      setting = build(:setting, pr_title_template: "100% patched, 50% off: %{gems}")

      expect(setting.render_pr_title(gems: "rack")).to eq("100% patched, 50% off: rack")
    end
  end

  describe "tooling_pr_title_template" do
    it "has a default" do
      expect(described_class.current.tooling_pr_title_template).to eq("chore(deps): update %{gems}")
    end

    it "rejects an unknown field" do
      setting = build(:setting, tooling_pr_title_template: "bump %{nope}")

      expect(setting).not_to be_valid
      expect(setting.errors[:tooling_pr_title_template].first).to include("nope")
    end

    it "is what render_pr_title uses for a tooling PR" do
      expect(build(:setting).render_pr_title(tooling: true, gems: "brakeman")).to eq("chore(deps): update brakeman")
    end
  end

  describe "branch_separator" do
    it "defaults to a dot" do
      expect(described_class.current.branch_separator).to eq(".")
    end

    it "accepts only the known separators" do
      expect(%w[/ . - _].map { build(:setting, branch_separator: it) }).to all(be_valid)
      expect(build(:setting, branch_separator: "/main")).not_to be_valid
      expect(build(:setting, branch_separator: "")).not_to be_valid
    end
  end

  describe "manual fix minutes" do
    it "defaults to 15–30" do
      expect(described_class.current).to have_attributes(manual_fix_minutes_low: 15, manual_fix_minutes_high: 30)
    end

    it "needs a positive low end no higher than the high end" do
      expect(build(:setting, manual_fix_minutes_low: 0)).not_to be_valid
      expect(build(:setting, manual_fix_minutes_low: 40, manual_fix_minutes_high: 30)).not_to be_valid
    end
  end

  describe "keep_current_gems" do
    it "defaults to none" do
      expect(described_class.current.keep_current_gems).to eq([])
    end

    it "is normalized to unique, non-blank names" do
      setting = create(:setting, keep_current_gems: [" brakeman ", "brakeman", ""])

      expect(setting.reload.keep_current_gems).to eq(%w[brakeman])
    end

    it "rejects something that isn't a gem name" do
      setting = build(:setting, keep_current_gems: ["brakeman", "../etc"])

      expect(setting).not_to be_valid
      expect(setting.errors[:keep_current_gems].first).to include("../etc")
    end
  end
end
