# A fake GitHub App: real RSA key, App id 123, and stubbed installation tokens.
module GithubAppHelpers
  GITHUB_API = "https://api.github.com".freeze

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def stub_installation_token(installation_id, token: "ghs_test_#{installation_id}")
    stub_request(:post, "#{GITHUB_API}/app/installations/#{installation_id}/access_tokens")
      .to_return(json_response({ token:, expires_at: 1.hour.from_now.iso8601 }, status: 201))
  end

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end

RSpec.shared_context "github app" do
  include GithubAppHelpers

  around do |example|
    with_env("GITHUB_APP_ID" => "123", "GITHUB_APP_PRIVATE_KEY" => GithubAppHelpers.private_key.to_pem) do
      example.run
    end
  end
end
