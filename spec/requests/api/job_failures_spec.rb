require "rails_helper"

RSpec.describe "Api::JobFailures", type: :request do
  before { sign_in_as(create(:user)) }

  def good_job(error:, finished_at:, job_class: "AdvisoryDbSyncJob")
    GoodJob::Job.create!(active_job_id: SecureRandom.uuid, job_class:, queue_name: "default",
      serialized_params: {}, error:, finished_at:)
  end

  it "lists jobs that failed in the last 24 hours, newest first" do
    good_job(error: "older failure", finished_at: 3.hours.ago, job_class: "ScanRepositoryJob")
    good_job(error: "OpenSSL::PKey::RSAError: bad key", finished_at: 1.hour.ago)
    good_job(error: nil, finished_at: 1.hour.ago)          # succeeded
    good_job(error: "ancient", finished_at: 2.days.ago)    # outside the window

    get "/api/job_failures"

    expect(response.parsed_body.pluck("job_class", "error")).to eq([
      ["AdvisoryDbSyncJob", "OpenSSL::PKey::RSAError: bad key"],
      ["ScanRepositoryJob", "older failure"]
    ])
  end
end
