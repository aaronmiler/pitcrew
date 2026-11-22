require "rails_helper"

RSpec.describe "Api::Resolvers", type: :request do
  it "lists resolver status against the repos that need them" do
    sign_in_as(create(:user))
    create(:repository, ecosystems: %w[bundler], runtimes: { "ruby" => "3.4.9" })
    stub_request(:get, "http://resolver34:9292/health").to_return(status: 200, body: { ok: true, runtimes: { ruby: "3.4.9" } }.to_json)

    with_resolvers({ "RESOLVER_RUBY_3_4" => "http://resolver34:9292" }) { get "/api/resolvers" }

    expect(response.parsed_body.sole).to include("runtime" => "ruby", "minor" => "3.4", "status" => "ok")
  end

  it "requires sign-in" do
    get "/api/resolvers"

    expect(response).to have_http_status(:unauthorized)
  end
end
