# A PR as Octokit returns it, with every field Github::FetchPullRequest reads.
module GithubDoubles
  def github_pull_request(state: "open", merged: false, head: "pr-head", merged_at: nil, closed_at: nil)
    closed_at ||= Time.current unless state == "open"
    merged_at ||= Time.current if merged
    double("github pull request", state:, merged:, merged_at:, closed_at:, head: double(sha: head))
  end
end

RSpec.configure { |config| config.include GithubDoubles }
