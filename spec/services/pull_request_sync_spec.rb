require "rails_helper"

RSpec.describe PullRequestSync do
  let(:repository) { create(:repository, full_name: "aaronmiler/app") }
  let(:pull_request) { create(:fix_pull_request, repository:, number: 7, branch: "pitcrew/security-1") }
  let!(:finding) { create(:finding, repository:, status: "in_pr", fix_pull_request: pull_request) }
  let(:client) { double("octokit", delete_branch: nil) }

  def github_pr(state:, merged: false)
    github_pull_request(state:, merged:, head: "head-sha",
      merged_at: (Time.utc(2026, 11, 21) if merged), closed_at: Time.utc(2026, 11, 21))
  end

  # runs: [[status, conclusion], ...]; turned into doubles inside the example.
  def stub_ci(combined_state: "success", combined_total: 0, runs: [])
    allow(client).to receive(:combined_status).and_return(double(state: combined_state, total_count: combined_total))
    check_runs = runs.map { |status, conclusion| double(status:, conclusion:) }
    allow(client).to receive(:check_runs_for_ref).and_return(double(check_runs:))
  end

  describe "an open PR" do
    before { allow(client).to receive(:pull_request).and_return(github_pr(state: "open")) }

    it "leaves head_sha as the head Pitcrew last left (the poll compares against it)" do
      pull_request.update!(head_sha: "pitcrew-head")
      stub_ci

      described_class.call(pull_request:, client:)

      expect(pull_request.reload.head_sha).to eq("pitcrew-head")
    end

    {
      "no checks yet" => [{}, "pending"],
      "all checks green" => [{ runs: [%w[completed success], %w[completed skipped]] }, "passing"],
      "a check still running" => [{ runs: [%w[completed success], ["in_progress", nil]] }, "pending"],
      "a failed check" => [{ runs: [%w[completed success], %w[completed failure]] }, "failing"],
      "a failed commit status" => [{ combined_state: "failure", combined_total: 1 }, "failing"]
    }.each do |description, (ci, expected)|
      it "records #{expected} CI for #{description}" do
        stub_ci(**ci)

        described_class.call(pull_request:, client:)

        expect(pull_request.reload).to have_attributes(ci_status: expected, state: "open")
      end
    end
  end

  it "records a merge, logs merged events, and deletes the branch" do
    allow(client).to receive(:pull_request).and_return(github_pr(state: "closed", merged: true))

    described_class.call(pull_request:, client:)

    expect(pull_request.reload).to have_attributes(state: "merged", merged_at: Time.utc(2026, 11, 21))
    expect(finding.reload.status).to eq("in_pr") # the next scan resolves it from the new lockfile
    expect(finding.events.pluck(:kind)).to eq(["merged"])
    expect(client).to have_received(:delete_branch).with("aaronmiler/app", "pitcrew/security-1")
  end

  it "treats closing without merging as a human's no" do
    allow(client).to receive(:pull_request).and_return(github_pr(state: "closed"))

    described_class.call(pull_request:, client:)

    expect(pull_request.reload.state).to eq("closed")
    expect(finding.reload).to have_attributes(status: "needs_attention", reason: "PR #7 was closed without merging.")
  end

  it "doesn't mind if GitHub already deleted the branch" do
    allow(client).to receive(:pull_request).and_return(github_pr(state: "closed", merged: true))
    allow(client).to receive(:delete_branch).and_raise(Octokit::UnprocessableEntity)

    expect { described_class.call(pull_request:, client:) }.not_to raise_error
  end
end
