FactoryBot.define do
  factory :finding do
    repository
    advisory
    locked_version { "3.1.0" }
    status { "open" }
    detected_at { Time.current }
  end
end
