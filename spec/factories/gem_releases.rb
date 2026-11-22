FactoryBot.define do
  factory :gem_release do
    sequence(:name) { |n| "gem-#{n}" }
    version { "1.0.0" }
    checked_at { Time.current }
  end
end
