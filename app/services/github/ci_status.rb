module Github
  # CI for a commit, from both check runs and legacy commit statuses:
  # "pending" (nothing reported yet, or still running), "failing", or "passing".
  class CiStatus < ApplicationService
    FAILING = %w[failure error timed_out cancelled action_required startup_failure].freeze

    def call(client:, repository:, sha:)
      states = []
      combined = client.combined_status(repository.full_name, sha)
      states << combined.state if combined.total_count.to_i.positive?
      client.check_runs_for_ref(repository.full_name, sha).check_runs.each do |run|
        states << (run.status == "completed" ? run.conclusion.to_s : "pending")
      end

      return "pending" if states.empty? || states.include?("pending")
      return "failing" if states.any? { FAILING.include?(it) }

      "passing"
    end
  end
end
