# Refreshes a Pitcrew PR from GitHub: CI status (of GitHub's head) while it's open; once it's
# merged or closed, records that (with events) and deletes its pitcrew branch.
# head_sha is deliberately left alone: it's the head Pitcrew last left the branch at, set by
# RepositoryFix, so PullRequestSyncJob can tell when someone else pushed.
#   merged -> findings stay in_pr until the next scan sees the new lockfile and resolves them
#   closed without merging -> its findings become needs_attention (a human said no)
class PullRequestSync < ApplicationService
  # Returns GitHub's view of the PR (Github::PullRequestState).
  def call(pull_request:, client: nil, with_ci: true)
    @pull_request = pull_request
    @repository = pull_request.repository
    @client = client || Github::InstallationClient.call(installation_id: @repository.installation_id)

    github = Github::FetchPullRequest.call(client: @client, repository: @repository, number: pull_request.number)
    if github.open?
      pull_request.update!(ci_status: Github::CiStatus.call(client: @client, repository: @repository, sha: github.head_sha)) if with_ci
    else
      finish(github)
    end
    github
  end

  private

  def finish(github)
    ActiveRecord::Base.transaction do
      if github.merged
        @pull_request.update!(state: "merged", merged_at: github.merged_at || Time.current)
        @pull_request.findings.in_pr.find_each { it.merged!(@pull_request) }
      else
        @pull_request.update!(state: "closed", closed_at: github.closed_at || Time.current)
        reason = "PR ##{@pull_request.number} was closed without merging."
        @pull_request.findings.in_pr.find_each { it.flag!(reason, pr: @pull_request.number) }
      end
    end
    Github::DeleteBranch.call(client: @client, repository: @repository, branch: @pull_request.branch)
  end
end
