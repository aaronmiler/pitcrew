require "rails_helper"

RSpec.describe Github::MergeDefaultBranch do
  let(:repository) { build(:repository, full_name: "aaronmiler/app", default_branch: "main") }
  let(:client) { double("octokit", merge: nil) }
  let(:branch) { "pitcrew/security-1" }

  def comparing(status, files: [])
    allow(client).to receive(:compare).with("aaronmiler/app", branch, "main")
      .and_return(double(status:, files: files.map { double(filename: it) }))
  end

  def merge
    described_class.call(client:, repository:, branch:)
  end

  it "merges the default branch in when its Gemfile.lock moved" do
    comparing("diverged", files: %w[Gemfile Gemfile.lock])

    expect(merge).to eq(:merged)
    expect(client).to have_received(:merge)
      .with("aaronmiler/app", branch, "main", commit_message: "Merge main into pitcrew/security-1")
  end

  it "leaves other default-branch changes for people to merge" do
    comparing("ahead", files: %w[app/models/user.rb])

    expect(merge).to eq(:skipped)
    expect(client).not_to have_received(:merge)
  end

  it "does nothing when the branch already has the default branch" do
    comparing("behind")

    expect(merge).to eq(:current)
    expect(client).not_to have_received(:merge)
  end

  it "raises Conflict for a person to resolve when GitHub can't merge cleanly" do
    comparing("diverged", files: %w[Gemfile.lock])
    allow(client).to receive(:merge).and_raise(Octokit::Conflict)

    expect { merge }.to raise_error(described_class::Conflict, /Merge it by hand/)
  end

  it "refuses to merge into anything but a pitcrew/ branch" do
    expect { described_class.call(client:, repository:, branch: "main") }.to raise_error(ArgumentError)
  end
end
