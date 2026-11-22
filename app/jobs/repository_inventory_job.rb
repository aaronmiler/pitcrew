class RepositoryInventoryJob < ApplicationJob
  def perform
    result = Github::SyncRepositories.call
    Rails.logger.info("[RepositoryInventoryJob] #{result}")
  end
end
