module Github
  # When GitHub's Advisory Database published and reviewed an advisory. Dependabot alerts
  # once GitHub has reviewed it, so this is the baseline for Pitcrew's head start.
  # The endpoint is public, and called anonymously: GitHub refuses installation tokens here
  # (403 "Resource not accessible by integration"). 60 requests/hour is plenty, since only
  # advisories new since the first import are looked up.
  class AdvisoryDates < ApplicationService
    def call(advisory:)
      return unless advisory.ghsa.to_s.match?(/\AGHSA(-[0-9a-z]{4}){3}\z/) # goes into a URL path

      data = Octokit::Client.new.get("advisories/#{advisory.ghsa}") # Octokit has no helper for this endpoint
      advisory.update!(ghsa_published_at: data.published_at, ghsa_reviewed_at: data.github_reviewed_at)
    rescue Octokit::NotFound
      nil # not in GitHub's database (yet)
    end
  end
end
