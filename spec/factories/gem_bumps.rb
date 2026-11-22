FactoryBot.define do
  factory :gem_bump do
    repository
    fix_pull_request { association :fix_pull_request, repository: }
    gem_name { "brakeman" }
    from_version { "7.0.0" }
    to_version { "8.1.1" }
  end
end
