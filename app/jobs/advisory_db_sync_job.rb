# Pulls ruby-advisory-db, indexes what changed, and rescans enabled repos if anything did.
class AdvisoryDbSyncJob < ApplicationJob
  def perform
    heads = AdvisoryDb::Sync.call
    return if heads[:before] == heads[:after]

    new_ids = AdvisoryDb::Import.call(**heads)
    # The first import is ~1,400 historical advisories; GitHub dates only matter for new ones.
    new_ids.each { |id| AdvisoryDatesJob.perform_later(id) } if heads[:before]

    Repository.enabled.find_each { |repository| ScanRepositoryJob.perform_later(repository.id, force: true) }
    Rails.logger.info("[AdvisoryDbSyncJob] #{heads[:before] || 'clone'}..#{heads[:after]}: #{new_ids.size} new")
  end
end
