require "rails_helper"

RSpec.describe "Api::ServiceIncidents", type: :request do
  before { sign_in_as(create(:user)) }

  it "lists the outages going on now" do
    create(:service_incident, component: "Git Operations", status: "major_outage", incident_name: "Git is down",
      incident_url: "https://stspg.io/x")
    create(:service_incident, component: "Actions", resolved_at: 1.minute.ago)

    get "/api/service_incidents"

    expect(response.parsed_body.sole).to include(
      "component" => "Git Operations", "status" => "major_outage",
      "incident_name" => "Git is down", "incident_url" => "https://stspg.io/x"
    )
  end
end
