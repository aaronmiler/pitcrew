require "rails_helper"

RSpec.describe Resolver::Client do
  around do |example|
    resolvers = {
      "RESOLVER_RUBY_3_3" => "http://resolver33:9292",
      "RESOLVER_RUBY_3_4" => " http://resolver34:9292/ ",
      "RESOLVER_NODE_22_0" => "http://node22:9292", # another runtime's sidecar
      "RESOLVER_WORK_ROOT" => "/work" # not a sidecar
    }
    with_resolvers(resolvers) { example.run }
  end

  let(:args) { { ruby_minor: "3.4", dir: "job1", gems: %w[rack], level: :patch } }

  it "reads one RESOLVER_<RUNTIME>_<MAJOR>_<MINOR> variable per sidecar" do
    expect(described_class.endpoints).to eq("3.3" => "http://resolver33:9292", "3.4" => "http://resolver34:9292")
    expect(described_class.endpoints("node")).to eq("22.0" => "http://node22:9292")
    expect(described_class.available?("3.2")).to be(false)
  end

  it "posts the request to the resolver for that Ruby minor" do
    request = stub_request(:post, "http://resolver34:9292/resolve/bundler")
      .with(body: { dir: "job1", packages: ["rack"], level: "patch", env: {} }.to_json)
      .to_return(status: 200, body: { ok: true, exit: 0, stdout: "done", stderr: "" }.to_json)

    result = described_class.call(**args)

    expect(request).to have_been_made
    expect(result).to have_attributes(ok: true, stdout: "done")
  end

  it "returns a failed resolve as a result, not an error" do
    stub_request(:post, "http://resolver34:9292/resolve/bundler")
      .to_return(status: 200, body: { ok: false, exit: 6, stdout: "", stderr: "conflict" }.to_json)

    expect(described_class.call(**args)).to have_attributes(ok: false, stderr: "conflict")
  end

  it "raises Unavailable when there's no resolver for that Ruby" do
    expect { described_class.call(**args, ruby_minor: "3.2") }
      .to raise_error(described_class::Unavailable, /no resolver for Ruby 3.2/)
  end

  it "raises Unavailable when the sidecar can't run Bundler" do
    stub_request(:post, "http://resolver34:9292/resolve/bundler").to_return(status: 404, body: { ok: false }.to_json)

    expect { described_class.call(**args) }.to raise_error(described_class::Unavailable, /can't run Bundler/)
  end

  it "raises Unavailable when the resolver is unreachable" do
    stub_request(:post, "http://resolver34:9292/resolve/bundler").to_raise(Errno::ECONNREFUSED)

    expect { described_class.call(**args) }.to raise_error(described_class::Unavailable, /unreachable/)
  end
end
