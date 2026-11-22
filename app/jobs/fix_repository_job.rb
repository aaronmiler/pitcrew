class FixRepositoryJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  # One fix per repo at a time; a duplicate waits its turn.
  good_job_control_concurrency_with(perform_limit: 1, key: -> { "fix-repository-#{arguments.first}" })

  def perform(repository_id, force: false)
    repository = Repository.enabled.find_by(id: repository_id)
    return unless repository

    result = begin
      RepositoryFix.call(repository:, force:)
    rescue StandardError => e
      repository.record_error!("fix", e)
      raise
    end
    repository.clear_error!("fix")
    Rails.logger.info("[FixRepositoryJob] #{repository.full_name}: #{result}")
  end
end
