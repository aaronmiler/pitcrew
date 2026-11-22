module Github
  # Rewrites a Pitcrew PR's title and body (they describe the whole PR, so each update
  # replaces them).
  class UpdatePullRequest < ApplicationService
    def call(client:, repository:, number:, title:, body:)
      client.update_pull_request(repository.full_name, number, title:, body:)
    end
  end
end
