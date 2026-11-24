require "rails_helper"

# The small PR services at the GitHub boundary. Their behaviour through Pitcrew's flows is
# covered by the RepositoryFix and PullRequestSync specs; this covers their own contracts.
RSpec.describe "Github pull request services" do
  let(:repository) { build(:repository, full_name: "aaronmiler/app", default_branch: "main") }
  let(:client) { double("octokit") }

  describe Github::FetchPullRequest do
    it "returns a plain value, not an Octokit resource" do
      allow(client).to receive(:pull_request).with("aaronmiler/app", 7)
        .and_return(github_pull_request(state: "closed", merged: true, head: "abc"))

      state = described_class.call(client:, repository:, number: 7)

      expect(state).to be_a(Github::PullRequestState).and have_attributes(state: "closed", merged: true, head_sha: "abc")
      expect(state).not_to be_open
    end
  end

  describe Github::OpenPullRequest do
    it "opens a PR from a pitcrew/ branch into the default branch" do
      allow(client).to receive(:create_pull_request).and_return(double(number: 9))

      expect(described_class.call(client:, repository:, branch: "pitcrew/security-1", title: "t", body: "b")).to eq(9)
      expect(client).to have_received(:create_pull_request).with("aaronmiler/app", "main", "pitcrew/security-1", "t", "b")
    end

    it "refuses any other branch" do
      expect { described_class.call(client:, repository:, branch: "main", title: "t", body: "b") }
        .to raise_error(ArgumentError, /refusing to write main/)
    end
  end

  describe Github::DeleteBranch do
    it "refuses to delete anything but a pitcrew branch" do
      allow(client).to receive(:delete_branch)

      expect { described_class.call(client:, repository:, branch: "main") }.to raise_error(ArgumentError)
      expect(client).not_to have_received(:delete_branch)
    end

    it "doesn't mind a branch that's already gone" do
      allow(client).to receive(:delete_branch).and_raise(Octokit::NotFound)

      expect { described_class.call(client:, repository:, branch: "pitcrew/security-1") }.not_to raise_error
    end
  end
end
