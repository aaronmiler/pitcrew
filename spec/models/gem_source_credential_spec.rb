require "rails_helper"

RSpec.describe GemSourceCredential, type: :model do
  subject { build(:gem_source_credential) }

  it { is_expected.to validate_presence_of(:secret) }
  it { is_expected.to validate_uniqueness_of(:host).case_insensitive }

  it "encrypts the secret at rest" do
    credential = create(:gem_source_credential, secret: "x-access-token:abc123")
    raw = described_class.connection.select_value(
      "SELECT secret FROM gem_source_credentials WHERE id = #{credential.id}"
    )

    expect(raw).not_to include("abc123")
    expect(credential.reload.secret).to eq("x-access-token:abc123")
  end

  it "normalizes the host" do
    expect(build(:gem_source_credential, host: "  RubyGems.PKG.GitHub.com ").host)
      .to eq("rubygems.pkg.github.com")
  end

  describe "#to_env" do
    it "uses Bundler's env key format for dots" do
      credential = build(:gem_source_credential, host: "rubygems.pkg.github.com", secret: "s")

      expect(credential.to_env).to eq("BUNDLE_RUBYGEMS__PKG__GITHUB__COM" => "s")
    end

    it "uses Bundler's env key format for dashes" do
      expect(build(:gem_source_credential, host: "my-gems.example.com").env_key)
        .to eq("BUNDLE_MY___GEMS__EXAMPLE__COM")
    end
  end

  it "keeps the secret out of #inspect" do
    expect(build(:gem_source_credential, secret: "abc123").inspect).not_to include("abc123")
  end
end
