class ScanRepositoryJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  # One scan per repo at a time; a duplicate just waits its turn.
  good_job_control_concurrency_with(perform_limit: 1, key: -> { "scan-repository-#{arguments.first}" })

  def perform(repository_id, force: false)
    repository = Repository.enabled.find_by(id: repository_id)
    return unless repository

    result = begin
      RepositoryScan.call(repository:, force:)
    rescue StandardError => e
      repository.record_error!("scan", e)
      raise
    end
    repository.clear_error!("scan")
    Rails.logger.info("[ScanRepositoryJob] #{repository.full_name}: #{result}")
    enqueue_fix(repository, result)
  end

  private

  # Fix when there are open findings, or a changed lockfile leaves a kept-current gem behind
  # (new releases are GemReleasesJob's trigger). With an open PR, also refresh it when the
  # default branch's lockfile changed (forced: merge the default branch in so the PR stays
  # current) or something resolved (the PR may have nothing left and should close).
  def enqueue_fix(repository, result)
    return if result.key?(:skipped)

    pr_open = repository.open_fix_pull_request.present?
    changed = result[:lockfile_changed]
    return unless repository.findings.open.exists? ||
                  (changed && repository.behind_gems.any?) ||
                  (pr_open && (changed || result[:resolved].to_i.positive?))

    FixRepositoryJob.perform_later(repository.id, force: pr_open && changed)
  end
end
