FactoryBot.define do
  factory :fix_pull_request do
    repository
    sequence(:number) { |n| n }
    sequence(:branch) { |n| "pitcrew/security-20261121-#{1000 + n}" }
    state { "open" }
    opened_at { Time.current }
  end
end
