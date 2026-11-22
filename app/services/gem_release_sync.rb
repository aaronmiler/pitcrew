# Refreshes GemRelease for every kept-current gem from rubygems.org, and drops rows for gems
# no longer listed. Returns the names whose latest version is new to Pitcrew (first seen, or
# a new release), which is when repos need a fix run.
class GemReleaseSync < ApplicationService
  URL = "https://rubygems.org/api/v1/versions/%s/latest.json".freeze

  def call(names: Setting.current.keep_current_gems)
    GemRelease.where.not(name: names).delete_all
    names.select { |name| refresh(name) }
  end

  private

  def refresh(name)
    version = latest(name) or return false

    release = GemRelease.find_or_initialize_by(name:)
    changed = release.version != version
    release.update!(version:, checked_at: Time.current)
    changed
  end

  # Stable releases only; rubygems.org answers "unknown" for a missing gem.
  def latest(name)
    response = HTTPX.get(format(URL, ERB::Util.url_encode(name)))
    if response.is_a?(HTTPX::ErrorResponse) || response.status != 200
      Rails.logger.warn("[GemReleaseSync] #{name}: #{response.is_a?(HTTPX::ErrorResponse) ? response.error.class : response.status}")
      return
    end

    version = JSON.parse(response.body.to_s)["version"].to_s
    version if Gem::Version.correct?(version) && !Gem::Version.new(version).prerelease?
  end
end
