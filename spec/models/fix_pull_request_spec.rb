require "rails_helper"

RSpec.describe FixPullRequest, type: :model do
  subject { build(:fix_pull_request) }

  it { is_expected.to belong_to(:repository) }
  it { is_expected.to have_many(:findings).dependent(:nullify) }
  it { is_expected.to validate_uniqueness_of(:number).scoped_to(:repository_id) }

  it "only allows pitcrew branches, with any of the separators" do
    expect(%w[/ . - _].map { build(:fix_pull_request, branch: "pitcrew#{it}security-1") }).to all(be_valid)
    expect(build(:fix_pull_request, branch: "main")).not_to be_valid
    expect(build(:fix_pull_request, branch: "pitcrewx-security-1")).not_to be_valid
  end

  it "rejects anything after the prefix that isn't a plain branch name" do
    ["pitcrew/", "pitcrew/a b", "pitcrew/x\nmain", "pitcrew/x~1"].each do |branch|
      expect(build(:fix_pull_request, branch:)).not_to be_valid, branch.inspect
    end
  end

  describe "one open PR per repository" do
    let(:repository) { create(:repository) }

    before { create(:fix_pull_request, repository:, state: "open") }

    it "rejects a second open PR" do
      expect(build(:fix_pull_request, repository:, state: "open")).not_to be_valid
    end

    it "is enforced by the database when validations are skipped" do
      second = build(:fix_pull_request, repository:, state: "open")

      expect { second.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows any number of merged or closed PRs" do
      create(:fix_pull_request, repository:, state: "merged")

      expect(build(:fix_pull_request, repository:, state: "closed")).to be_valid
    end

    it "allows an open PR on another repository" do
      expect(build(:fix_pull_request, state: "open")).to be_valid
    end
  end

  describe ".branch_name" do
    let(:repository) { create(:repository) }
    let(:at) { Time.utc(2026, 11, 21, 23, 32) }

    it "builds a dated branch in UTC with the configured separator" do
      expect(described_class.branch_name(repository:, at:)).to eq("pitcrew.security-20261121")

      Setting.current.update!(branch_separator: "/")
      expect(described_class.branch_name(repository:, at:)).to eq("pitcrew/security-20261121")
    end

    it "counts up when the repo already had a PR that day" do
      create(:fix_pull_request, repository:, state: "merged", branch: "pitcrew.security-20261121")
      expect(described_class.branch_name(repository:, at:)).to eq("pitcrew.security-20261121-2")

      create(:fix_pull_request, repository:, state: "merged", branch: "pitcrew.security-20261121-2")
      expect(described_class.branch_name(repository:, at:)).to eq("pitcrew.security-20261121-3")
    end

    it "ignores other repos' branches" do
      create(:fix_pull_request, state: "merged", branch: "pitcrew.security-20261121")

      expect(described_class.branch_name(repository:, at:)).to eq("pitcrew.security-20261121")
    end
  end
end
