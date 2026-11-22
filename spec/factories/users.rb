FactoryBot.define do
  factory :user do
    sequence(:github_uid) { |n| 5_000 + n }
    sequence(:github_login) { |n| "user#{n}" }
    name { "Test User" }
  end
end
