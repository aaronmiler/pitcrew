module Api
  # Background jobs that failed recently, from GoodJob's records. Covers jobs that aren't
  # tied to one repo too (advisory sync, PR sync, repo inventory), so a broken pipeline is
  # visible instead of quietly going stale. `incident` is a GitHub outage that was going on
  # when the job failed, if any.
  class JobFailuresController < BaseController
    WINDOW = 24.hours
    LIMIT = 10

    def index
      failures = GoodJob::Job.where.not(error: nil).where(finished_at: WINDOW.ago..)
        .order(finished_at: :desc).limit(LIMIT)
      render json: failures.map { |job|
        { job_class: job.job_class, error: job.error.to_s.truncate(500), finished_at: job.finished_at,
          incident: ServiceIncident.at_as_hash(job.finished_at) }
      }
    end
  end
end
