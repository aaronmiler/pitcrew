require "rails_helper"

RSpec.describe Lockfile::Versions do
  subject(:versions) { described_class.new(fixture_lockfile("family")) }

  it "maps gems to versions, collapsing platform variants" do
    expect(versions.versions).to include("actionpack" => "8.1.3", "nokogiri" => "1.18.0")
  end

  it "reads the Gemfile's own requirement from DEPENDENCIES" do
    expect(versions.gemfile_requirement("rack-proxy")).to eq("~> 0.8")
    expect(versions.gemfile_requirement("nokogiri")).to be_nil # no requirement
    expect(versions.gemfile_requirement("rack")).to be_nil     # not a direct dependency
  end

  it "lists changed versions between two lockfiles" do
    changes = described_class.changes(fixture_lockfile("rack_vulnerable"), fixture_lockfile("rack_patched"))

    expect(changes.map { [it.name, it.from, it.to] }).to eq([%w[rack 3.1.0 3.1.24], %w[rack-session 2.0.0 2.1.2]])
  end
end
