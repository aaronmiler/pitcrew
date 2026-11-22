require "rails_helper"

RSpec.describe Users::SignIn do
  def sign_in(uid: 1, login: "aaronmiler", **)
    described_class.call(uid:, login:, **)
  end

  # dotenv may load a real PITCREW_INITIAL_USER in test; start from none.
  around { |example| with_env("PITCREW_INITIAL_USER" => nil) { example.run } }
  before { allow(Github::OrgMember).to receive(:call).and_return(false) }

  describe "initial user bootstrap" do
    around { |example| with_env("PITCREW_INITIAL_USER" => "AaronMiler") { example.run } }

    it "lets the initial user in while there are no users, matching login case-insensitively" do
      user = sign_in(login: "aaronmiler")

      expect(user).to have_attributes(github_uid: 1, github_login: "aaronmiler", access_via: "direct")
    end

    it "is ignored once any user exists" do
      create(:user, github_login: "someone-else")

      expect(sign_in(login: "aaronmiler")).to be_nil
    end

    it "doesn't let anyone else in" do
      expect(sign_in(login: "mallory")).to be_nil
      expect(User.count).to eq(0)
    end
  end

  it "fails closed when no initial user is configured" do
    with_env("PITCREW_INITIAL_USER" => nil) do
      expect(sign_in).to be_nil
    end
  end

  describe "known users" do
    it "lets a direct user in by uid and refreshes their profile" do
      user = create(:user, github_uid: 1, github_login: "old-login", access_via: "direct")

      expect(sign_in(uid: 1, login: "new-login", name: "Aaron")).to eq(user)
      expect(user.reload).to have_attributes(github_login: "new-login", name: "Aaron")
    end

    it "doesn't let a renamed login take over someone else's account" do
      create(:user, github_uid: 1, github_login: "aaronmiler")

      expect(sign_in(uid: 2, login: "aaronmiler")).to be_nil
    end

    it "lets an org user in only while they're still a member" do
      Setting.current.update!(allowed_orgs: ["acme"])
      user = create(:user, github_uid: 1, github_login: "aaronmiler", access_via: "org")

      allow(Github::OrgMember).to receive(:call).with(org: "acme", login: "aaronmiler").and_return(true)
      expect(sign_in).to eq(user)

      allow(Github::OrgMember).to receive(:call).with(org: "acme", login: "aaronmiler").and_return(false)
      expect(sign_in).to be_nil
    end
  end

  describe "invites" do
    it "claims a pending invite by login and binds the uid" do
      invite = create(:user, github_uid: nil, github_login: "Teammate")

      expect(sign_in(uid: 7, login: "teammate")).to eq(invite)
      expect(invite.reload.github_uid).to eq(7)
    end

    it "can't be claimed again by a different uid once bound" do
      create(:user, github_uid: 7, github_login: "teammate")

      expect(sign_in(uid: 8, login: "teammate")).to be_nil
    end
  end

  describe "allowed orgs" do
    before { Setting.current.update!(allowed_orgs: %w[acme widgets]) }

    it "creates an org user for a member of any allowed org" do
      allow(Github::OrgMember).to receive(:call).with(org: "widgets", login: "newbie").and_return(true)

      expect(sign_in(uid: 9, login: "newbie")).to have_attributes(github_uid: 9, access_via: "org")
    end

    it "rejects a non-member" do
      expect(sign_in(uid: 9, login: "outsider")).to be_nil
    end
  end
end
