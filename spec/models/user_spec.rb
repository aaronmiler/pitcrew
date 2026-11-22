require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:github_login) }
  it { is_expected.to validate_uniqueness_of(:github_uid).allow_nil }

  describe "invited users" do
    it "can exist without a github_uid until they sign in" do
      user = create(:user, github_uid: nil)

      expect(user).to be_pending
      expect(described_class.pending).to contain_exactly(user)
    end

    it "allows several pending users at once" do
      create(:user, github_uid: nil)

      expect { create(:user, github_uid: nil) }.not_to raise_error
    end
  end

  describe "github_login" do
    it "is unique regardless of case" do
      create(:user, github_login: "AaronMiler")

      expect(build(:user, github_login: "aaronmiler")).not_to be_valid
    end

    it "is unique regardless of case at the database level" do
      create(:user, github_login: "AaronMiler")

      expect { build(:user, github_login: "aaronmiler").save(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".find_by_login" do
    it "matches case-insensitively and ignores surrounding whitespace" do
      user = create(:user, github_login: "AaronMiler")

      expect(described_class.find_by_login(" aaronmiler ")).to eq(user)
    end
  end
end
