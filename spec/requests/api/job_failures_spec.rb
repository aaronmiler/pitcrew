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

  it "notes a GitHub outage that was going on when a job failed" do
    create(:service_incident, component: "API Requests", started_at: 2.hours.ago, resolved_at: 30.minutes.ago)
    good_job(error: "Octokit::BadGateway", finished_at: 1.hour.ago)
    good_job(error: "unrelated", finished_at: 10.minutes.ago)

    get "/api/job_failures"

    incidents = response.parsed_body.pluck("error", "incident").to_h
    expect(incidents["Octokit::BadGateway"]).to include("component" => "API Requests", "status" => "degraded_performance")
    expect(incidents["unrelated"]).to be_nil
  end
end
