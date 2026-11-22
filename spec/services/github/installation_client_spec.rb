require "rails_helper"

RSpec.describe Github::InstallationClient do
  include_context "github app"

  it "exchanges the App JWT for an installation token" do
    request = stub_installation_token(42, token: "ghs_abc")

    client = described_class.call(installation_id: 42)

    expect(client.access_token).to eq("ghs_abc")
    expect(request.with { |req| req.headers["Authorization"].start_with?("Bearer ") }).to have_been_made
  end
end
