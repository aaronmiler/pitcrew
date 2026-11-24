require "rails_helper"

RSpec.describe "Api::Settings", type: :request do
  include ActiveJob::TestHelper

  before { sign_in_as(create(:user)) }

  it "shows settings with the available title fields" do
    get "/api/settings"

    expect(response.parsed_body).to include(
      "pr_title_template" => "chore(security): patch %{advisories} in %{gems}",
      "tooling_pr_title_template" => "chore(deps): update %{gems}",
      "allowed_orgs" => [],
      "keep_current_gems" => [],
      "pr_title_fields" => %w[count advisories gems gem_count ids repo date],
      "branch_separator" => ".",
      "branch_separators" => %w[/ . - _]
    )
  end

  it "updates the branch separator and rejects an unknown one" do
    patch "/api/settings", params: { setting: { branch_separator: "-" } }, as: :json
    expect(Setting.current.branch_separator).to eq("-")

    patch "/api/settings", params: { setting: { branch_separator: "+" } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates the title template and allowed orgs" do
    patch "/api/settings", params: { setting: { pr_title_template: "fix: %{gems}", allowed_orgs: ["Acme"] } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(Setting.current).to have_attributes(pr_title_template: "fix: %{gems}", allowed_orgs: ["acme"])
  end

  it "rejects a template with an unknown field" do
    patch "/api/settings", params: { setting: { pr_title_template: "fix: %{nope}" } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to include("nope")
  end

  it "updates kept-current gems and checks their releases" do
    patch "/api/settings",
      params: { setting: { keep_current_gems: ["brakeman"], tooling_pr_title_template: "deps: %{gems}" } }, as: :json

    expect(Setting.current).to have_attributes(keep_current_gems: ["brakeman"], tooling_pr_title_template: "deps: %{gems}")
    expect(GemReleasesJob).to have_been_enqueued
  end

  it "doesn't check releases when the gem list is unchanged" do
    patch "/api/settings", params: { setting: { pr_title_template: "fix: %{gems}" } }, as: :json

    expect(GemReleasesJob).not_to have_been_enqueued
  end
end
