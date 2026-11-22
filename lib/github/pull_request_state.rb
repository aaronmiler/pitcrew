module Github
  # A PR as GitHub reported it (Github::FetchPullRequest), as a plain value.
  class PullRequestState
    attr_reader :state, :merged, :merged_at, :closed_at, :head_sha

    def initialize(state:, merged:, merged_at:, closed_at:, head_sha:)
      @state = state
      @merged = merged
      @merged_at = merged_at
      @closed_at = closed_at
      @head_sha = head_sha
    end

    def open?
      state == "open"
    end
  end
end
