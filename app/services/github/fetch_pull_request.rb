module Github
  # A PR as GitHub has it now. Returns a PullRequestState.
  class FetchPullRequest < ApplicationService
    def call(client:, repository:, number:)
      github = client.pull_request(repository.full_name, number)
      PullRequestState.new(
        state: github.state, merged: github.merged, merged_at: github.merged_at,
        closed_at: github.closed_at, head_sha: github.head.sha
      )
    end
  end
end
