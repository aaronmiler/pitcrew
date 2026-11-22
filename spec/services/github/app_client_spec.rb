require "rails_helper"

RSpec.describe Github::AppClient do
  include_context "github app"

  it "authenticates as the App with a short-lived RS256 JWT" do
    token = described_class.call.bearer_token
    payload, header = JWT.decode(token, GithubAppHelpers.private_key.public_key, true, algorithm: "RS256")

    expect(header["alg"]).to eq("RS256")
    expect(payload["iss"]).to eq("123")
    expect(payload["exp"] - Time.current.to_i).to be <= 10.minutes.to_i
  end

  it "accepts the key on one line with literal \\n separators (what foreman and Docker env files allow)" do
    one_line = GithubAppHelpers.private_key.to_pem.gsub("\n", '\n')

    with_env("GITHUB_APP_PRIVATE_KEY" => one_line) do
      token = described_class.call.bearer_token
      expect { JWT.decode(token, GithubAppHelpers.private_key.public_key, true, algorithm: "RS256") }.not_to raise_error
    end
  end

  it "explains a truncated key instead of a bare OpenSSL error" do
    with_env("GITHUB_APP_PRIVATE_KEY" => "-----BEGIN RSA PRIVATE KEY-----") do
      expect { described_class.call }.to raise_error(OpenSSL::PKey::RSAError, /put it on one line/)
    end
  end
end
