require "rails_helper"

RSpec.describe PullRequestSyncJob, type: :job do
  include ActiveJob::TestHelper

  let(:pull_request) { create(:fix_pull_request, head_sha: "pitcrew-head") }

  def github(state: "open", head: "pitcrew-head")
    allow(PullRequestSync).to receive(:call).with(pull_request:).and_return(Github::PullRequestState.new(state:, merged: false, merged_at: nil, closed_at: nil, head_sha: head))
  end

  it "queues a forced fix when someone else pushed to the branch" do
    github(head: "their-head")

    described_class.perform_now

    expect(FixRepositoryJob).to have_been_enqueued.with(pull_request.repository_id, force: true)
  end

  it "leaves the PR alone when its head is still Pitcrew's" do
    github

    described_class.perform_now

    expect(FixRepositoryJob).not_to have_been_enqueued
  end

  it "ignores PRs that just merged or closed" do
    github(state: "closed", head: "their-head")

    described_class.perform_now

    expect(FixRepositoryJob).not_to have_been_enqueued
  end

  it "keeps going when one PR fails" do
    create(:fix_pull_request, head_sha: "x")
    allow(PullRequestSync).to receive(:call).and_raise(Octokit::BadGateway)

    expect { described_class.perform_now }.not_to raise_error
  end
end
