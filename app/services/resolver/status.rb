module Resolver
  # Which resolver sidecars the repos need versus which are configured and answering, so a
  # missing one shows up before a fix fails. One row per [runtime, minor], needed or
  # configured; Ruby only for now:
  #   { runtime: "ruby", minor: "3.4", url:, status:, reported:, repos: [{ id:, full_name:, enabled: }] }
  # status: ok | unreachable | mismatch (answers with another Ruby) | missing (not configured)
  #       | unknown (Ruby repos with no .ruby-version; minor is nil)
  class Status < ApplicationService
    HEALTH_TIMEOUT = 2 # seconds

    def call
      endpoints = Client.endpoints
      needing = ruby_repos.group_by { it.runtime_minor(:ruby) }
      health = ping(endpoints)

      minors = (needing.keys.compact | endpoints.keys).sort_by { Gem::Version.new(it) }.reverse
      rows = minors.map do |minor|
        url = endpoints[minor]
        reported = health[minor]
        { runtime: "ruby", minor:, url:, status: status(url, reported, minor), reported:, repos: repo_list(needing[minor]) }
      end
      rows << { runtime: "ruby", minor: nil, url: nil, status: "unknown", reported: nil, repos: repo_list(needing[nil]) } if needing[nil]
      rows
    end

    private

    # Repos that resolve with Ruby: detected bundler repos, plus enabled repos a sync
    # hasn't checked yet.
    def ruby_repos
      Repository.order(:full_name).select do |repo|
        repo.ecosystems.nil? ? repo.enabled? : repo.ecosystems.intersect?(Repository::RUBY_ECOSYSTEMS)
      end
    end

    def status(url, reported, minor)
      return "missing" unless url
      return "unreachable" unless reported
      Repository.minor_of(:ruby, reported) == minor ? "ok" : "mismatch"
    end

    # { minor => the Ruby version its sidecar reports }, for the ones that answered.
    def ping(endpoints)
      return {} if endpoints.empty?

      responses = HTTPX.with(timeout: { request_timeout: HEALTH_TIMEOUT }).get(*endpoints.values.map { "#{it}/health" })
      responses = [responses] if endpoints.one?
      endpoints.keys.zip(responses).to_h do |minor, response|
        ruby = JSON.parse(response.body.to_s).dig("runtimes", "ruby") if !response.is_a?(HTTPX::ErrorResponse) && response.status == 200
        [minor, ruby]
      rescue JSON::ParserError
        [minor, nil]
      end.compact
    end

    def repo_list(repos)
      (repos || []).map { { id: it.id, full_name: it.full_name, enabled: it.enabled } }
    end
  end
end
