module Github
  # Opens a PR from a pitcrew/* branch into the default branch. Returns its number.
  class OpenPullRequest < ApplicationService
    def call(client:, repository:, branch:, title:, body:)
      Github.ensure_pitcrew_branch!(branch)
      client.create_pull_request(repository.full_name, repository.default_branch, branch, title, body).number
    end
  end
end
