# Polls open Pitcrew PRs (tars isn't reachable for webhooks): CI status, merges, closes.
# A head that isn't the one Pitcrew last left means someone pushed to the branch: queue a
# forced fix so Pitcrew re-reads it (e.g. bumps a kept-current gem a rollback reverted,
# credits advisories fixed by hand).
class PullRequestSyncJob < ApplicationJob
  def perform
    FixPullRequest.open.includes(:repository).find_each do |pull_request|
      github = PullRequestSync.call(pull_request:)
      if github.open? && github.head_sha != pull_request.head_sha
        FixRepositoryJob.perform_later(pull_request.repository_id, force: true)
      end
    rescue Octokit::Error => e
      Rails.logger.warn("[PullRequestSyncJob] #{pull_request.repository.full_name}##{pull_request.number}: #{e.class}")
    end
  end
end
