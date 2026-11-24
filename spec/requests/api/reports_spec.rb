require "rails_helper"

RSpec.describe "Api::Reports", type: :request do
  it "returns the summary for the range" do
    sign_in_as(create(:user))

    get "/api/report", params: { range: "90d" }

    expect(response.parsed_body).to include("range" => "90d", "totals" => hash_including("auto_fixed" => 0))
  end

  it "falls back to 30 days for an unknown range" do
    sign_in_as(create(:user))

    get "/api/report", params: { range: "forever" }

    expect(response.parsed_body["range"]).to eq("30d")
  end

  it "requires sign-in" do
    get "/api/report"

    expect(response).to have_http_status(:unauthorized)
  end
end
