FactoryBot.define do
  factory :repository do
    sequence(:github_id) { |n| 1_000 + n }
    sequence(:full_name) { |n| "aaronmiler/app-#{n}" }
    default_branch { "main" }
    installation_id { 42 }
    enabled { true }
    runtimes { { "ruby" => "3.4.9" } }
  end
end
