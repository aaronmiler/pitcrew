module Github
  # Shallow, read-only clone of one branch (the default branch, or an open PR's branch), so
  # the resolver sees the Gemfile and anything it references. Nothing is ever pushed from it: commits go through the API.
  # The token reaches git via env (GIT_CONFIG_*), never argv or .git/config.
  class Checkout < ApplicationService
    def call(repository:, dir:, branch: repository.default_branch, url: "https://github.com/#{repository.full_name}.git")
      token = InstallationClient.call(installation_id: repository.installation_id).access_token
      Command.run!(
        "git", "clone", "--quiet", "--depth", "1", "--single-branch", "--branch", branch, url, dir,
        env: auth_env(token)
      )
      {
        head: Command.run!("git", "rev-parse", "HEAD", chdir: dir),
        tree: Command.run!("git", "rev-parse", "HEAD^{tree}", chdir: dir),
        token:
      }
    end

    private

    def auth_env(token)
      basic = Base64.strict_encode64("x-access-token:#{token}")
      {
        "GIT_CONFIG_COUNT" => "1",
        "GIT_CONFIG_KEY_0" => "http.https://github.com/.extraheader",
        "GIT_CONFIG_VALUE_0" => "Authorization: Basic #{basic}",
        "GIT_TERMINAL_PROMPT" => "0"
      }
    end
  end
end
