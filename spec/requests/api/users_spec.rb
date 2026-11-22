require "rails_helper"

RSpec.describe "Api::Users", type: :request do
  let(:me) { create(:user) }

  before { sign_in_as(me) }

  it "lists users" do
    create(:user, github_login: "teammate")

    get "/api/users"

    expect(response.parsed_body.pluck("github_login")).to include(me.github_login, "teammate")
  end

  it "invites a login as a pending direct user" do
    post "/api/users", params: { github_login: "newbie" }, as: :json

    expect(response).to have_http_status(:created)
    expect(User.find_by_login("newbie")).to have_attributes(pending?: true, access_via: "direct")
  end

  it "turns an existing org user into a direct user instead of duplicating them" do
    org_user = create(:user, github_login: "OrgPerson", access_via: "org")

    post "/api/users", params: { github_login: "orgperson" }, as: :json

    expect(org_user.reload.access_via).to eq("direct")
    expect(User.where("lower(github_login) = 'orgperson'").count).to eq(1)
  end

  it "removes a user" do
    other = create(:user)

    delete "/api/users/#{other.id}"

    expect(response).to have_http_status(:no_content)
    expect(User.exists?(other.id)).to be(false)
  end

  it "won't let you remove yourself" do
    delete "/api/users/#{me.id}"

    expect(response).to have_http_status(:unprocessable_content)
    expect(User.exists?(me.id)).to be(true)
  end

  describe "CSRF" do
    around do |example|
      Api::BaseController.allow_forgery_protection = true
      example.run
    ensure
      Api::BaseController.allow_forgery_protection = false
    end

    it "rejects a state-changing request without a CSRF token" do
      post "/api/users", params: { github_login: "sneaky" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.find_by_login("sneaky")).to be_nil
    end
  end
end
