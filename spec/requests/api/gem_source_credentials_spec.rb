require "rails_helper"

RSpec.describe "Api::GemSourceCredentials", type: :request do
  before { sign_in_as(create(:user)) }

  it "never returns the secret" do
    create(:gem_source_credential, host: "gems.contribsys.com", secret: "user:pass")

    get "/api/gem_source_credentials"

    expect(response.parsed_body).to match([include("host" => "gems.contribsys.com", "env_key" => "BUNDLE_GEMS__CONTRIBSYS__COM")])
    expect(response.body).not_to include("user:pass")
  end

  it "creates one" do
    post "/api/gem_source_credentials", params: { host: "rubygems.pkg.github.com", secret: "ghp_x" }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.body).not_to include("ghp_x")
    expect(GemSourceCredential.find_by!(host: "rubygems.pkg.github.com").secret).to eq("ghp_x")
  end

  it "replaces a secret but not the host" do
    credential = create(:gem_source_credential, host: "gems.contribsys.com", secret: "old")

    patch "/api/gem_source_credentials/#{credential.id}", params: { secret: "new", host: "evil.com" }, as: :json

    expect(credential.reload).to have_attributes(secret: "new", host: "gems.contribsys.com")
  end

  it "rejects a duplicate host" do
    create(:gem_source_credential, host: "gems.contribsys.com")

    post "/api/gem_source_credentials", params: { host: "GEMS.contribsys.com", secret: "x" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "deletes one" do
    credential = create(:gem_source_credential)

    delete "/api/gem_source_credentials/#{credential.id}"

    expect(GemSourceCredential.exists?(credential.id)).to be(false)
  end
end
