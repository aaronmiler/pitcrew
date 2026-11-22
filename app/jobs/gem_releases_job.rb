# Checks rubygems.org for new releases of the kept-current gems. On one, refreshes every
# enabled repo that's now behind (forced, so an open PR gets the default branch merged in).
class GemReleasesJob < ApplicationJob
  def perform
    new_releases = GemReleaseSync.call
    return if new_releases.empty?

    Repository.enabled.find_each do |repository|
      FixRepositoryJob.perform_later(repository.id, force: true) if repository.behind_gems(new_releases).any?
    end
    Rails.logger.info("[GemReleasesJob] new: #{new_releases.join(', ')}")
  end
end
