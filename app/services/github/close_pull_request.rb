module Github
  # Closes a Pitcrew PR with a comment saying why.
  class ClosePullRequest < ApplicationService
    def call(client:, repository:, number:, comment:)
      client.add_comment(repository.full_name, number, comment)
      client.close_pull_request(repository.full_name, number)
    end
  end
end
