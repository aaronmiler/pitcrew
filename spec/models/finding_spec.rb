require "rails_helper"

RSpec.describe Finding, type: :model do
  subject { build(:finding) }

  it { is_expected.to belong_to(:repository) }
  it { is_expected.to belong_to(:advisory) }
  it { is_expected.to belong_to(:fix_pull_request).optional }
  it { is_expected.to validate_presence_of(:locked_version) }
  it { is_expected.to validate_uniqueness_of(:advisory_id).scoped_to(:repository_id) }

  it "takes its ecosystem from the advisory" do
    expect(build(:finding, advisory: build(:advisory, ecosystem: "npm")).ecosystem).to eq("npm")
  end

  it "rejects an unknown status" do
    expect(build(:finding, status: "bogus")).not_to be_valid
  end

  it "lists events in the order they happened" do
    finding = create(:finding)
    later = create(:finding_event, finding:, kind: "pr_opened", occurred_at: 1.hour.ago)
    earlier = create(:finding_event, finding:, kind: "detected", occurred_at: 2.hours.ago)

    expect(finding.events).to eq([earlier, later])
  end

  describe "state changes" do
    let(:finding) { create(:finding, status: "open") }
    let(:pull_request) { create(:fix_pull_request, repository: finding.repository, number: 7) }

    it "detects: reopens with the locked version and a detected event" do
      finding.update!(status: "resolved", resolved_at: 1.day.ago, reason: "old")

      finding.detect!("3.1.0")

      expect(finding).to have_attributes(status: "open", locked_version: "3.1.0", resolved_at: nil, reason: nil)
      expect(finding.events.last).to have_attributes(kind: "detected", metadata: { "locked_version" => "3.1.0" })
    end

    it "resolves with a resolved event" do
      finding.resolve!

      expect(finding).to have_attributes(status: "resolved", resolved_at: be_present)
      expect(finding.events.pluck(:kind)).to eq(["resolved"])
    end

    it "moves into a PR with one event, not one per re-publish" do
      finding.move_to_pr!(pull_request, :pr_opened)
      finding.move_to_pr!(pull_request, :pr_updated)

      expect(finding).to have_attributes(status: "in_pr", fix_pull_request: pull_request)
      expect(finding.events.map { [it.kind, it.metadata] }).to eq([["pr_opened", { "pr" => 7 }]])
    end

    it "gets a new event when it moves to a different PR" do
      finding.move_to_pr!(pull_request, :pr_opened)
      pull_request.update!(state: "closed", closed_at: Time.current) # one open PR per repo
      newer = create(:fix_pull_request, repository: finding.repository, number: 8)

      finding.move_to_pr!(newer, :pr_opened)

      expect(finding.events.map { it.metadata["pr"] }).to eq([7, 8])
    end

    it "flags with one event, keeping the latest reason" do
      finding.flag!("The Gemfile requires rack ~> 2.0.", pr: 7)
      finding.flag!("No patch or minor release clears it.")

      expect(finding).to have_attributes(status: "needs_attention", reason: "No patch or minor release clears it.")
      expect(finding.events.map { [it.kind, it.metadata] }).to eq([
        ["needs_attention", { "reason" => "The Gemfile requires rack ~> 2.0.", "pr" => 7 }]
      ])
    end

    it "records a merge without changing status" do
      finding.move_to_pr!(pull_request, :pr_opened)
      pull_request.update!(state: "merged", merged_at: 1.minute.ago)

      finding.merged!(pull_request)

      expect(finding.status).to eq("in_pr")
      expect(finding.events.find_by(kind: "merged").occurred_at).to be_within(1.second).of(pull_request.merged_at)
    end
  end
end
