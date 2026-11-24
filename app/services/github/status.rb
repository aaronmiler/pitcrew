require "net/http"

module Github
  # The state of the GitHub components Pitcrew depends on, from githubstatus.com's public
  # Statuspage summary (not the GitHub API, so no Octokit). Returns a ComponentStatus for
  # each of COMPONENTS that the page lists. Raises Unavailable when the page can't be read.
  class Status < ApplicationService
    class Unavailable < StandardError; end

    URL = URI("https://www.githubstatus.com/api/v2/summary.json")

    # What each one breaks: API Requests (sync, PRs, CI checks), Git Operations (clone, push,
    # the advisory DB), Pull Requests (open/update/merge), Actions (CI on our PRs stalls),
    # Packages (private gems on rubygems.pkg.github.com).
    COMPONENTS = ["API Requests", "Git Operations", "Pull Requests", "Actions", "Packages"].freeze

    def call
      summary = fetch
      incidents = summary.fetch("incidents", [])
      summary.fetch("components", []).filter_map do |component|
        next unless COMPONENTS.include?(component["name"])

        incident = incidents.find { |i| i.fetch("components", []).any? { it["id"] == component["id"] } }
        ComponentStatus.new(
          name: component["name"], status: component["status"],
          incident_name: incident&.dig("name"), incident_url: incident&.dig("shortlink")
        )
      end
    end

    private

    def fetch
      response = Net::HTTP.start(URL.host, URL.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.get(URL.request_uri)
      end
      raise Unavailable, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Unavailable, "#{e.class}: #{e.message}"
    end
  end
end
