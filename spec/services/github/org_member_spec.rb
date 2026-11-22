require "rails_helper"

RSpec.describe Github::OrgMember do
  include_context "github app"

  let(:api) { GithubAppHelpers::GITHUB_API }

  before do
    stub_request(:get, "#{api}/orgs/acme/installation").to_return(json_response({ id: 77 }))
    stub_installation_token(77)
  end

  it "is true when GitHub says the login is a member" do
    stub_request(:get, "#{api}/orgs/acme/members/aaron").to_return(status: 204)

    expect(described_class.call(org: "acme", login: "aaron")).to be(true)
  end

  it "is false when GitHub says the login is not a member" do
    stub_request(:get, "#{api}/orgs/acme/members/aaron").to_return(status: 404)

    expect(described_class.call(org: "acme", login: "aaron")).to be(false)
  end

  it "is false when the App isn't installed on the org" do
    stub_request(:get, "#{api}/orgs/other/installation").to_return(status: 404)

    expect(described_class.call(org: "other", login: "aaron")).to be(false)
  end
end
