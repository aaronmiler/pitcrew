require "rails_helper"

RSpec.describe Github::AdvisoryDates do
  include_context "github app"

  let(:advisory) { create(:advisory, ghsa: "GHSA-9j94-67jr-4cqj") }

  it "stores GitHub's published and reviewed times" do
    stub_request(:get, "https://api.github.com/advisories/GHSA-9j94-67jr-4cqj").to_return(json_response({
      published_at: "2025-05-08T12:00:00Z", github_reviewed_at: "2025-05-09T15:30:00Z"
    }))

    described_class.call(advisory:)

    expect(advisory.reload).to have_attributes(
      ghsa_published_at: Time.utc(2025, 5, 8, 12), ghsa_reviewed_at: Time.utc(2025, 5, 9, 15, 30)
    )
  end

  it "asks anonymously, even with an installation around (GitHub refuses its token here)" do
    create(:repository)
    request = stub_request(:get, "https://api.github.com/advisories/GHSA-9j94-67jr-4cqj")
      .with { |req| !req.headers.key?("Authorization") }
      .to_return(json_response({ published_at: "2025-05-08T12:00:00Z", github_reviewed_at: nil }))

    described_class.call(advisory:)

    expect(request).to have_been_made
  end

  it "leaves the dates empty when GitHub doesn't have the advisory" do
    stub_request(:get, "https://api.github.com/advisories/GHSA-9j94-67jr-4cqj").to_return(status: 404)

    described_class.call(advisory:)

    expect(advisory.reload.ghsa_reviewed_at).to be_nil
  end

  it "skips anything that isn't a well-formed GHSA id (it goes into a URL path)" do
    advisory.update!(ghsa: "GHSA-../../x")

    expect { described_class.call(advisory:) }.not_to raise_error
    expect(a_request(:any, /api.github.com/)).not_to have_been_made
  end
end
