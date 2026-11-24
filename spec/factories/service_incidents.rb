FactoryBot.define do
  factory :service_incident do
    source { "github" }
    component { "API Requests" }
    status { "degraded_performance" }
    started_at { 10.minutes.ago }
  end
end
