require "rails_helper"

RSpec.describe Github::CommitLockfile do
  let(:repository) { build(:repository, full_name: "aaronmiler/app") }
  let(:client) { double("octokit") }
  let(:base) { { head: "base-head", tree: "base-tree" } }

  before do
    allow(client).to receive_messages(
      create_blob: "blob-sha", create_tree: double(sha: "tree-sha"), create_commit: double(sha: "commit-sha"),
      create_ref: nil, update_ref: nil
    )
  end

  def commit(new_branch:, branch: "pitcrew/security-1")
    described_class.call(client:, repository:, branch:, lockfile: "LOCK", base:, message: "fix", new_branch:)
  end

  it "builds the tree on the checkout's tree, replacing only Gemfile.lock" do
    commit(new_branch: true)

    expect(client).to have_received(:create_tree).with(
      "aaronmiler/app", [{ path: "Gemfile.lock", mode: "100644", type: "blob", sha: "blob-sha" }], base_tree: "base-tree"
    )
  end

  it "starts a new branch on top of the checkout" do
    expect(commit(new_branch: true)).to eq("commit-sha")
    expect(client).to have_received(:create_commit).with("aaronmiler/app", "fix", "tree-sha", ["base-head"])
    expect(client).to have_received(:create_ref).with("aaronmiler/app", "heads/pitcrew/security-1", "commit-sha")
  end

  it "adds to an existing branch on top of its head, fast-forward only" do
    commit(new_branch: false)

    expect(client).to have_received(:create_commit).with("aaronmiler/app", "fix", "tree-sha", ["base-head"])
    expect(client).to have_received(:update_ref).with("aaronmiler/app", "heads/pitcrew/security-1", "commit-sha", false)
  end

  it "commits nothing when the branch already has this exact lockfile" do
    allow(client).to receive(:create_tree).and_return(double(sha: "base-tree"))

    expect(commit(new_branch: false)).to be_nil
    expect(client).not_to have_received(:create_commit)
    expect(client).not_to have_received(:update_ref)
  end

  it "refuses to write anything but a pitcrew/ branch" do
    expect { commit(new_branch: false, branch: "main") }.to raise_error(ArgumentError, /refusing to write main/)
    expect(client).not_to have_received(:create_blob)
  end
end
