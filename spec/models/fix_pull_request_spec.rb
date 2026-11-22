require "rails_helper"

RSpec.describe FixPullRequest, type: :model do
  subject { build(:fix_pull_request) }

  it { is_expected.to belong_to(:repository) }
  it { is_expected.to have_many(:findings).dependent(:nullify) }
  it { is_expected.to validate_uniqueness_of(:number).scoped_to(:repository_id) }

  it "only allows pitcrew/ branches" do
    expect(build(:fix_pull_request, branch: "main")).not_to be_valid
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
    it "builds a timestamped pitcrew branch in UTC" do
      at = Time.utc(2026, 11, 21, 14, 32)

      expect(described_class.branch_name(at:)).to eq("pitcrew/security-20261121-1432")
    end
  end
end
