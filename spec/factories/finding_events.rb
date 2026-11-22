FactoryBot.define do
  factory :finding_event do
    finding
    kind { "detected" }
    occurred_at { Time.current }
  end
end
