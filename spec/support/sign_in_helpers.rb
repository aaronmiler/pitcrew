OmniAuth.config.test_mode = true
OmniAuth.config.logger = Logger.new(IO::NULL) # the failed-sign-in spec logs an expected error

# Signs in through the real OmniAuth callback, with GitHub's response mocked.
module SignInHelpers
  def mock_github_identity(uid:, login:, name: nil, email: nil)
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: uid.to_s, info: { nickname: login, name:, email: }
    )
  end

  def sign_in_as(user)
    mock_github_identity(uid: user.github_uid, login: user.github_login)
    get "/auth/github/callback"
  end
end

RSpec.configure do |config|
  config.include SignInHelpers, type: :request
  config.after { OmniAuth.config.mock_auth[:github] = nil }
end
