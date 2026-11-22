# Queues a scan of every enabled repo. Each scan is cheap when the lockfile hasn't changed.
class ScanRepositoriesJob < ApplicationJob
  def perform
    Repository.enabled.find_each { |repository| ScanRepositoryJob.perform_later(repository.id) }
  end
end
