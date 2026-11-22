# Sign-in uses the GitHub App's OAuth credentials. GitHub Apps ignore OAuth scopes;
# what the user token can do comes from the App's permissions.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github, ENV["GITHUB_APP_CLIENT_ID"], ENV["GITHUB_APP_CLIENT_SECRET"]
end

# Start sign-in with POST only (omniauth-rails_csrf_protection checks the token).
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.on_failure = ->(env) { SessionsController.action(:failure).call(env) }
