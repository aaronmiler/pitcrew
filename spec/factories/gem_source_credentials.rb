FactoryBot.define do
  factory :gem_source_credential do
    sequence(:host) { |n| "gems#{n}.example.com" }
    secret { "user:token" }
  end
end
