require "rails_helper"

RSpec.describe "Api::Session", type: :request do
  it "returns 401 JSON when signed out" do
    get "/api/session"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("error" => "unauthorized")
  end

  it "returns the signed-in user" do
    user = create(:user, github_login: "aaronmiler")
    sign_in_as(user)

    get "/api/session"

    expect(response.parsed_body).to include("id" => user.id, "github_login" => "aaronmiler", "pending" => false)
  end
end
