require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "sends signed-out visitors to the sign-in page" do
    get "/"

    expect(response).to redirect_to("/sign_in")
  end

  it "shows a GitHub sign-in button that POSTs" do
    get "/sign_in"

    expect(response.body).to include("Sign in with GitHub").and include('action="/auth/github"')
  end

  it "signs in an allowed user and lands on the app" do
    user = create(:user)

    sign_in_as(user)
    expect(response).to redirect_to("/")

    get "/"
    expect(response).to have_http_status(:ok)
  end

  it "rejects a GitHub identity without access" do
    mock_github_identity(uid: 404, login: "outsider")

    get "/auth/github/callback"

    expect(response).to redirect_to("/sign_in")
    expect(flash[:alert]).to include("doesn't have access")
  end

  it "handles a failed GitHub sign-in" do
    OmniAuth.config.mock_auth[:github] = :invalid_credentials

    get "/auth/github/callback"

    expect(response).to redirect_to("/sign_in")
    expect(flash[:alert]).to include("didn't complete")
  end

  it "signs out" do
    sign_in_as(create(:user))

    delete "/sign_out"
    get "/"

    expect(response).to redirect_to("/sign_in")
  end

  it "doesn't start sign-in from a GET (CSRF-safe login)" do
    get "/auth/github"

    # Falls through to the app shell's sign-in redirect; never to GitHub.
    expect(response).to redirect_to("/sign_in")
  end
end
