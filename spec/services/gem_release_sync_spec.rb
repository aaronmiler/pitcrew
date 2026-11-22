require "rails_helper"

RSpec.describe GemReleaseSync do
  def stub_latest(name, version, status: 200)
    stub_request(:get, "https://rubygems.org/api/v1/versions/#{name}/latest.json")
      .to_return(status:, body: { version: }.to_json)
  end

  it "records the latest release and reports it as new" do
    stub_latest("brakeman", "8.1.1")

    expect(described_class.call(names: ["brakeman"])).to eq(["brakeman"])
    expect(GemRelease.find_by!(name: "brakeman")).to have_attributes(version: "8.1.1", checked_at: be_present)
  end

  it "reports nothing new when the version is unchanged" do
    create(:gem_release, name: "brakeman", version: "8.1.1")
    stub_latest("brakeman", "8.1.1")

    expect(described_class.call(names: ["brakeman"])).to eq([])
  end

  it "ignores prereleases, unknown gems and failed requests" do
    stub_latest("brakeman", "9.0.0.pre1")
    stub_latest("nope", "unknown")
    stub_latest("down", "", status: 503)

    expect(described_class.call(names: %w[brakeman nope down])).to eq([])
    expect(GemRelease.count).to eq(0)
  end

  it "drops gems no longer kept current" do
    create(:gem_release, name: "rubocop")

    described_class.call(names: [])

    expect(GemRelease.count).to eq(0)
  end
end
