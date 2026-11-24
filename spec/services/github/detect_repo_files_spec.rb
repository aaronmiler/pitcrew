require "rails_helper"

RSpec.describe Github::DetectRepoFiles do
  include GithubAppHelpers

  let(:api) { GithubAppHelpers::GITHUB_API }
  let(:client) { Octokit::Client.new(access_token: "token") }

  it "checks every repo's lockfiles and reads its .ruby-version, in one query" do
    stub = stub_request(:post, "#{api}/graphql")
      .with do |request|
        query = JSON.parse(request.body)["query"]
        query.include?('r1: repository(owner: "aaronmiler", name: "delta")') &&
          query.include?('npm: object(expression: "HEAD:package-lock.json") { ... on Blob { oid } }') &&
          query.include?('ruby_version: object(expression: "HEAD:.ruby-version") { ... on Blob { text } }')
      end
      .to_return(json_response({ data: {
        r0: { bundler: { oid: "a" }, npm: nil, yarn: nil, pnpm: nil, ruby_version: { text: "3.4.9\n" } },
        r1: { bundler: { oid: "b" }, npm: nil, yarn: { oid: "c" }, pnpm: nil, ruby_version: nil }
      } }))

    result = described_class.call(client:, full_names: %w[aaronmiler/summit aaronmiler/delta])

    expect(result).to eq(
      "aaronmiler/summit" => { ecosystems: %w[bundler], ruby: "3.4.9" },
      "aaronmiler/delta" => { ecosystems: %w[bundler yarn], ruby: nil }
    )
    expect(stub).to have_been_requested.once
  end

  it "ignores a .ruby-version that isn't a version" do
    stub_request(:post, "#{api}/graphql")
      .to_return(json_response({ data: { r0: { bundler: { oid: "a" }, ruby_version: { text: "use the system ruby" } } } }))

    expect(described_class.call(client:, full_names: %w[aaronmiler/app])).to eq("aaronmiler/app" => { ecosystems: %w[bundler], ruby: nil })
  end

  it "records a repo with no lockfiles as having no ecosystems" do
    stub_request(:post, "#{api}/graphql").to_return(json_response({ data: { r0: { bundler: nil, npm: nil } } }))

    expect(described_class.call(client:, full_names: %w[aaronmiler/docs])).to eq("aaronmiler/docs" => { ecosystems: [], ruby: nil })
  end

  it "batches large installations" do
    stub_request(:post, "#{api}/graphql").to_return(json_response({ data: {} }))

    described_class.call(client:, full_names: Array.new(described_class::BATCH + 1) { "aaronmiler/repo-#{it}" })

    expect(a_request(:post, "#{api}/graphql")).to have_been_made.twice
  end

  it "skips a batch GitHub errors on and keeps going" do
    stub_request(:post, "#{api}/graphql")
      .to_return({ status: 502, body: "Bad Gateway" }, json_response({ data: { r0: { bundler: { oid: "a" } } } }))

    result = described_class.call(client:, full_names: Array.new(described_class::BATCH + 1) { "aaronmiler/repo-#{it}" })

    expect(result).to eq("aaronmiler/repo-#{described_class::BATCH}" => { ecosystems: %w[bundler], ruby: nil })
  end

  it "leaves out repos GitHub couldn't resolve" do
    stub_request(:post, "#{api}/graphql").to_return(json_response({ data: { r0: nil }, errors: [{ type: "NOT_FOUND" }] }))

    expect(described_class.call(client:, full_names: %w[aaronmiler/gone])).to eq({})
  end
end
