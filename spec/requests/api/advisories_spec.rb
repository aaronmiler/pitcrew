require "rails_helper"

RSpec.describe "Api::Advisories", type: :request do
  before { sign_in_as(create(:user)) }

  it "lists newest published first, with how many repos each affects" do
    # first_seen_at points the other way: publish date wins.
    older = create(:advisory, package_name: "rack", published_on: Date.new(2024, 1, 1), first_seen_at: 1.hour.ago)
    newer = create(:advisory, package_name: "puma", published_on: Date.new(2025, 6, 1), first_seen_at: 2.days.ago)
    undated = create(:advisory, package_name: "nokogiri", published_on: nil)
    create(:finding, advisory: older, status: "open")
    create(:finding, advisory: older, status: "open")
    create(:finding, advisory: older, status: "resolved")

    get "/api/advisories"

    expect(response.parsed_body.map { it.slice("id", "affected_repositories") }).to eq([
      { "id" => newer.id, "affected_repositories" => 0 },
      { "id" => older.id, "affected_repositories" => 2 },
      { "id" => undated.id, "affected_repositories" => 0 }
    ])
  end

  it "searches by gem, CVE or GHSA" do
    create(:advisory, package_name: "rack", cve: "CVE-2025-1111", ghsa: nil)
    create(:advisory, package_name: "puma", cve: nil, ghsa: "GHSA-abcd-efgh-ijkl")

    get "/api/advisories", params: { q: "RAC" }
    expect(response.parsed_body.pluck("package_name")).to eq(["rack"])

    get "/api/advisories", params: { q: "2025-1111" }
    expect(response.parsed_body.pluck("package_name")).to eq(["rack"])

    get "/api/advisories", params: { q: "abcd" }
    expect(response.parsed_body.pluck("package_name")).to eq(["puma"])
  end

  it "treats % and _ in the search literally" do
    create(:advisory, package_name: "rack")

    get "/api/advisories", params: { q: "%" }

    expect(response.parsed_body).to eq([])
  end
end
