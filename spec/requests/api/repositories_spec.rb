require "rails_helper"

RSpec.describe "Api::Repositories", type: :request do
  include ActiveJob::TestHelper

  let!(:repository) { create(:repository, full_name: "aaronmiler/esther", enabled: true) }

  before { sign_in_as(create(:user)) }

  describe "GET /api/repositories" do
    it "lists repos with unresolved finding counts and the open PR" do
      create(:repository, full_name: "aaronmiler/other", enabled: false)
      create(:finding, repository:, status: "open")
      create(:finding, repository:, status: "needs_attention")
      create(:finding, repository:, status: "resolved")
      create(:fix_pull_request, repository:, number: 12, ci_status: "passing")

      get "/api/repositories"

      esther, other = response.parsed_body
      expect(esther).to include(
        "full_name" => "aaronmiler/esther",
        "finding_counts" => { "open" => 1, "in_pr" => 0, "needs_attention" => 1 },
        "open_pull_request" => include("number" => 12, "ci_status" => "passing",
          "url" => "https://github.com/aaronmiler/esther/pull/12")
      )
      expect(other).to include("enabled" => false, "open_pull_request" => nil)
    end
  end

  it "serializes times as ISO 8601, which browsers parse reliably" do
    repository.update!(last_scanned_at: Time.utc(2026, 11, 22, 5, 43, 32))

    get "/api/repositories"

    expect(response.parsed_body.first["last_scanned_at"]).to eq("2026-11-22T05:43:32.000Z")
  end

  describe "GET /api/repositories/:id" do
    it "shows unresolved findings, PRs and recent events" do
      finding = create(:finding, repository:, status: "needs_attention", reason: "Needs a major")
      create(:finding, repository:, status: "resolved")
      create(:finding_event, finding:, kind: "detected")
      create(:fix_pull_request, repository:, state: "merged")

      get "/api/repositories/#{repository.id}"

      body = response.parsed_body
      expect(body["findings"].pluck("reason")).to eq(["Needs a major"])
      expect(body["resolved_count"]).to eq(1)
      expect(body["pull_requests"].pluck("state")).to eq(["merged"])
      expect(body["events"].first).to include("kind" => "detected", "package_name" => finding.advisory.package_name)
    end
  end

  it "says whether a resolver is configured for each repo's Ruby" do
    create(:repository, full_name: "aaronmiler/on34", runtimes: { "ruby" => "3.4.9" })
    create(:repository, full_name: "aaronmiler/on26", runtimes: { "ruby" => "2.6.10" })
    create(:repository, full_name: "aaronmiler/unknown", runtimes: {})

    with_resolvers({ "RESOLVER_RUBY_3_4" => "http://resolver34:9292" }) { get "/api/repositories" }

    expect(response.parsed_body.to_h { [it["full_name"], it["resolver_configured"]] }).to include(
      "aaronmiler/on34" => true, "aaronmiler/on26" => false, "aaronmiler/unknown" => nil
    )
  end

  describe "GET /api/repositories/by_name/:owner/:name" do
    it "shows the repo by its full name, ignoring case" do
      get "/api/repositories/by_name/AaronMiler/Esther"

      expect(response.parsed_body).to include("id" => repository.id, "full_name" => "aaronmiler/esther")
    end

    it "finds names with dots" do
      dotted = create(:repository, full_name: "aaronmiler/pitcrew.rb")

      get "/api/repositories/by_name/aaronmiler/pitcrew.rb"

      expect(response.parsed_body["id"]).to eq(dotted.id)
    end

    it "404s for a repo it doesn't know" do
      get "/api/repositories/by_name/aaronmiler/nope"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/repositories/:id" do
    it "enables a repo and scans it right away" do
      repository.update!(enabled: false)

      patch "/api/repositories/#{repository.id}", params: { enabled: true }, as: :json

      expect(repository.reload.enabled).to be(true)
      expect(ScanRepositoryJob).to have_been_enqueued.with(repository.id, force: true)
    end

    it "disables a repo without scanning" do
      patch "/api/repositories/#{repository.id}", params: { enabled: false }, as: :json

      expect(repository.reload.enabled).to be(false)
      expect(ScanRepositoryJob).not_to have_been_enqueued
    end

    it "only lets enabled and ruby_minor change" do
      patch "/api/repositories/#{repository.id}", params: { enabled: true, full_name: "evil/repo" }, as: :json

      expect(repository.reload.full_name).to eq("aaronmiler/esther")
    end

    it "sets the Ruby to resolve with, and clears it with a blank" do
      patch "/api/repositories/#{repository.id}", params: { ruby_minor: "3.3" }, as: :json
      expect(repository.reload.ruby_minor).to eq("3.3")

      patch "/api/repositories/#{repository.id}", params: { ruby_minor: "" }, as: :json
      expect(repository.reload.ruby_minor).to be_nil
    end

    it "rejects a Ruby that isn't a minor" do
      patch "/api/repositories/#{repository.id}", params: { ruby_minor: "3.3.6" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(repository.reload.ruby_minor).to be_nil
    end
  end

  describe "actions" do
    it "queues a forced scan" do
      post "/api/repositories/#{repository.id}/scan"

      expect(response).to have_http_status(:accepted)
      expect(ScanRepositoryJob).to have_been_enqueued.with(repository.id, force: true)
    end

    it "won't scan a disabled repo" do
      repository.update!(enabled: false)

      post "/api/repositories/#{repository.id}/scan"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "queues a repo sync" do
      post "/api/repositories/sync"

      expect(RepositoryInventoryJob).to have_been_enqueued
    end
  end
end
