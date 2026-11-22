FactoryBot.define do
  factory :advisory do
    ecosystem { "rubygems" }
    package_name { "rack" }
    sequence(:cve) { |n| "CVE-2026-#{10_000 + n}" }
    ghsa { nil }
    sequence(:source_id) { |n| cve || ghsa || "ADV-#{n}" }
    title { "Example vulnerability" }
    url { "https://example.com/advisory" }
    criticality { "high" }
    patched_versions { [">= 3.1.24"] }
    first_seen_at { Time.current }
  end
end
