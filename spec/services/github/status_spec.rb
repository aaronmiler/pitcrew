require "rails_helper"

RSpec.describe Github::Status do
  let(:url) { "https://www.githubstatus.com/api/v2/summary.json" }

  it "returns the watched components, with the incident that lists them" do
    stub_request(:get, url).to_return(status: 200, body: Rails.root.join("spec/fixtures/github_status/summary.json").read)

    components = described_class.call.index_by(&:name)

    expect(components.keys).to match_array(described_class::COMPONENTS)
    expect(components["API Requests"]).to have_attributes(
      status: "degraded_performance",
      incident_name: "Disruption with some GitHub services",
      incident_url: "https://stspg.io/abc123"
    )
    expect(components["Actions"]).to have_attributes(status: "partial_outage", incident_name: nil)
    expect(components["Git Operations"]).to be_operational
  end

  it "raises Unavailable when the page errors" do
    stub_request(:get, url).to_return(status: 503, body: "")

    expect { described_class.call }.to raise_error(described_class::Unavailable, /503/)
  end

  it "raises Unavailable when the page times out or isn't JSON" do
    stub_request(:get, url).to_timeout
    expect { described_class.call }.to raise_error(described_class::Unavailable)

    stub_request(:get, url).to_return(status: 200, body: "<html>")
    expect { described_class.call }.to raise_error(described_class::Unavailable)
  end
end
