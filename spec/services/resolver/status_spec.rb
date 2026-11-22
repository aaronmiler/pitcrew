require "rails_helper"

RSpec.describe Resolver::Status do
  around do |example|
    resolvers = %w[3_4 3_3 3_2 3_1].to_h { ["RESOLVER_RUBY_#{it}", "http://resolver#{it.delete('_')}:9292"] }
    with_resolvers(resolvers) { example.run }
  end

  def health(host, ruby)
    stub_request(:get, "http://#{host}:9292/health").to_return(status: 200, body: { ok: true, runtimes: { ruby: } }.to_json)
  end

  before do
    health("resolver34", "3.4.9")
    health("resolver33", "3.4.9") # mapped as 3.3, but it's the 3.4 sidecar
    stub_request(:get, "http://resolver32:9292/health").to_timeout
    health("resolver31", "3.1.6")
  end

  let!(:on34) { create(:repository, full_name: "aaronmiler/a", ecosystems: %w[bundler], runtimes: { "ruby" => "3.4.9" }) }
  let!(:on34_disabled) { create(:repository, full_name: "aaronmiler/b", enabled: false, ecosystems: %w[bundler], runtimes: { "ruby" => "3.4.1" }) }
  let!(:on35) { create(:repository, full_name: "aaronmiler/c", ecosystems: %w[bundler], runtimes: { "ruby" => "3.5.0" }) }
  let!(:no_ruby) { create(:repository, full_name: "aaronmiler/d", ecosystems: %w[bundler], runtimes: {}) }

  def rows
    described_class.call.index_by { it[:minor] }
  end

  it "lists every needed or configured Ruby, newest first, with what's wrong" do
    expect(described_class.call.map { it.values_at(:minor, :status) }).to eq([
      ["3.5", "missing"], ["3.4", "ok"], ["3.3", "mismatch"], ["3.2", "unreachable"], ["3.1", "ok"], [nil, "unknown"]
    ])
  end

  it "lists the repos each one serves" do
    expect(rows["3.4"][:repos]).to eq([
      { id: on34.id, full_name: "aaronmiler/a", enabled: true },
      { id: on34_disabled.id, full_name: "aaronmiler/b", enabled: false }
    ])
    expect(rows["3.5"][:repos].pluck(:full_name)).to eq(["aaronmiler/c"])
    expect(rows[nil][:repos].pluck(:full_name)).to eq(["aaronmiler/d"])
    expect(rows["3.1"][:repos]).to be_empty # configured, unused
  end

  it "reports what a mismatched sidecar runs" do
    expect(rows["3.3"]).to include(reported: "3.4.9", url: "http://resolver33:9292")
  end

  it "counts only repos that resolve with Ruby" do
    create(:repository, full_name: "aaronmiler/js", ecosystems: %w[npm], runtimes: { "ruby" => "3.0.7" })
    create(:repository, full_name: "aaronmiler/unsynced", enabled: false, ecosystems: nil, runtimes: { "ruby" => "3.0.7" })
    create(:repository, full_name: "aaronmiler/unsynced-enabled", ecosystems: nil, runtimes: { "ruby" => "2.7.8" })

    expect(rows.keys).to include("2.7")
    expect(rows.keys).not_to include("3.0")
  end

  it "is empty with no resolvers and no Ruby repos" do
    Repository.delete_all

    with_resolvers({}) { expect(described_class.call).to eq([]) }
  end
end
