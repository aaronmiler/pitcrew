require "rails_helper"

RSpec.describe Github::SyncRepositories do
  include_context "github app"

  let(:api) { GithubAppHelpers::GITHUB_API }

  before do
    stub_request(:get, %r{\A#{api}/app/installations(\?|\z)}).to_return(json_response([{ id: 42 }]))
    stub_installation_token(42)
    repositories = {
      total_count: 2,
      repositories: [
        { id: 1, full_name: "aaronmiler/summit", default_branch: "main" },
        { id: 2, full_name: "aaronmiler/delta-renamed", default_branch: "trunk" }
      ]
    }
    stub_request(:get, %r{\A#{api}/installation/repositories(\?|\z)}).to_return(json_response(repositories))
    stub_request(:post, "#{api}/graphql").to_return(
      json_response({ data: {
        r0: { bundler: { oid: "abc" }, npm: nil, ruby_version: { text: "3.4.9\n" } },
        r1: { bundler: nil, yarn: { oid: "def" }, ruby_version: nil }
      } })
    )
  end

  it "adds new repos disabled" do
    described_class.call

    expect(Repository.find_by(github_id: 1)).to have_attributes(
      full_name: "aaronmiler/summit", installation_id: 42, enabled: false
    )
  end

  it "updates known repos without touching enabled" do
    create(:repository, github_id: 2, full_name: "aaronmiler/delta", default_branch: "main", enabled: true)

    described_class.call

    expect(Repository.find_by(github_id: 2)).to have_attributes(
      full_name: "aaronmiler/delta-renamed", default_branch: "trunk", enabled: true
    )
  end

  it "records each repo's ecosystems and runtimes" do
    described_class.call

    expect(Repository.find_by(github_id: 1)).to have_attributes(ecosystems: %w[bundler], runtimes: { "ruby" => "3.4.9" })
    expect(Repository.find_by(github_id: 2)).to have_attributes(ecosystems: %w[yarn], runtimes: {})
  end

  it "keeps what it knew when GitHub can't resolve a repo" do
    create(:repository, github_id: 2, ecosystems: %w[bundler], runtimes: { "ruby" => "3.3.6" })
    stub_request(:post, "#{api}/graphql").to_return(json_response({ data: { r0: {}, r1: nil } }))

    described_class.call

    expect(Repository.find_by(github_id: 2)).to have_attributes(ecosystems: %w[bundler], runtimes: { "ruby" => "3.3.6" })
  end

  it "disables repos the App can no longer see" do
    gone = create(:repository, github_id: 999, enabled: true)

    described_class.call

    expect(gone.reload.enabled).to be(false)
  end

  it "reports what it did" do
    create(:repository, github_id: 999, enabled: true)

    expect(described_class.call).to eq(seen: 2, created: 2, disabled: 1)
  end
end
