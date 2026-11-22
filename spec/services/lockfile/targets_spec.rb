require "rails_helper"

RSpec.describe Lockfile::Targets do
  let(:content) { fixture_lockfile("family") }

  it "pulls in every gem linked by exact pins, in both directions" do
    expect(described_class.call(content:, gems: ["activesupport"])).to eq(%w[actionpack actionview activesupport])
  end

  it "doesn't follow loose (>=, ~>) requirements" do
    expect(described_class.call(content:, gems: ["rack"])).to eq(["rack"])
    expect(described_class.call(content:, gems: ["unrelated"])).to eq(["unrelated"])
  end

  it "merges families and dedupes" do
    expect(described_class.call(content:, gems: %w[rack actionview rack]))
      .to eq(%w[actionpack actionview activesupport rack])
  end
end
