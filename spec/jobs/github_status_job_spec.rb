require "rails_helper"

RSpec.describe GithubStatusJob, type: :job do
  def github(*components)
    allow(Github::Status).to receive(:call).and_return(components)
  end

  def component(name, status, **incident)
    Github::ComponentStatus.new(name:, status:, **incident)
  end

  it "opens an incident for a component that isn't operational" do
    github(component("API Requests", "major_outage", incident_name: "API down", incident_url: "https://stspg.io/x"),
      component("Git Operations", "operational"))

    described_class.perform_now

    expect(ServiceIncident.open.sole).to have_attributes(
      source: "github", component: "API Requests", status: "major_outage",
      incident_name: "API down", incident_url: "https://stspg.io/x"
    )
  end

  it "updates the open incident instead of opening another" do
    incident = create(:service_incident, status: "degraded_performance")
    github(component("API Requests", "major_outage", incident_name: "Worse now"))

    described_class.perform_now

    expect(incident.reload).to have_attributes(status: "major_outage", incident_name: "Worse now", resolved_at: nil)
    expect(ServiceIncident.count).to eq(1)
  end

  it "resolves the incident when the component is operational again" do
    incident = create(:service_incident)
    github(component("API Requests", "operational"))

    described_class.perform_now

    expect(incident.reload.resolved_at).to be_present
  end

  it "changes nothing when the status page can't be read" do
    incident = create(:service_incident)
    allow(Github::Status).to receive(:call).and_raise(Github::Status::Unavailable, "HTTP 503")

    expect { described_class.perform_now }.not_to raise_error
    expect(incident.reload.resolved_at).to be_nil
  end
end
