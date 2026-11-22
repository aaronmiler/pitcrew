require "rails_helper"

RSpec.describe "SPA routes", type: :request do
  it "serves the app shell for client-side routes when signed in" do
    sign_in_as(create(:user))

    get "/repos/1"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="root"')
  end

  it "still requires sign-in" do
    get "/settings"

    expect(response).to redirect_to("/sign_in")
  end

  it "doesn't swallow unknown API paths" do
    sign_in_as(create(:user))

    get "/api/nope"

    expect(response).to have_http_status(:not_found)
  end
end
