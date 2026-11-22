require "rails_helper"

RSpec.describe Repository, type: :model do
  subject { build(:repository) }

  it { is_expected.to have_many(:findings).dependent(:destroy) }
  it { is_expected.to have_many(:fix_pull_requests).dependent(:destroy) }
  it { is_expected.to have_many(:gem_bumps).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_uniqueness_of(:full_name) }
  it { is_expected.to validate_uniqueness_of(:github_id) }

  describe "#runtime_minor" do
    it "reduces a full version to its minor line" do
      expect(build(:repository, runtimes: { "ruby" => "3.4.9" }).runtime_minor(:ruby)).to eq("3.4")
    end

    it "handles a ruby- prefix" do
      expect(build(:repository, runtimes: { "ruby" => "ruby-3.3.6" }).runtime_minor(:ruby)).to eq("3.3")
    end

    it "is nil without a version for that runtime" do
      expect(build(:repository, runtimes: {}).runtime_minor(:ruby)).to be_nil
    end
  end

  describe ".ruby_version_from" do
    it "reads a .ruby-version file's version" do
      expect(described_class.ruby_version_from("3.4.9\n")).to eq("3.4.9")
      expect(described_class.ruby_version_from("ruby-3.3.6")).to eq("ruby-3.3.6")
      expect(described_class.ruby_version_from("3.5.0-preview1")).to eq("3.5.0-preview1")
    end

    it "ignores anything that isn't a version" do
      expect(described_class.ruby_version_from("../../etc/passwd")).to be_nil
      expect(described_class.ruby_version_from("")).to be_nil
      expect(described_class.ruby_version_from(nil)).to be_nil
    end
  end

  describe "#with_runtime" do
    let(:repository) { build(:repository, runtimes: { "ruby" => "3.3.6", "node" => "22.11.0" }) }

    it "replaces one runtime and keeps the rest" do
      expect(repository.with_runtime(:ruby, "3.4.9")).to eq("ruby" => "3.4.9", "node" => "22.11.0")
    end

    it "drops a runtime whose version went away" do
      expect(repository.with_runtime(:ruby, nil)).to eq("node" => "22.11.0")
    end
  end

  describe "#open_fix_pull_request" do
    it "returns only the open PR" do
      repository = create(:repository)
      create(:fix_pull_request, repository:, state: "merged")
      open_pr = create(:fix_pull_request, repository:, state: "open")

      expect(repository.open_fix_pull_request).to eq(open_pr)
    end
  end

  describe "recorded job errors" do
    let(:repository) { create(:repository) }

    it "records an error with its source" do
      repository.record_error!("scan", RuntimeError.new("boom"))

      expect(repository.reload).to have_attributes(last_error: "RuntimeError: boom", last_error_source: "scan",
        last_error_at: be_present)
    end

    it "caps long messages" do
      repository.record_error!("fix", RuntimeError.new("x" * 5_000))

      expect(repository.reload.last_error.length).to eq(1_000)
    end

    it "clears only an error from the same source" do
      repository.record_error!("fix", RuntimeError.new("resolver down"))

      repository.clear_error!("scan")
      expect(repository.reload.last_error).to eq("RuntimeError: resolver down")

      repository.clear_error!("fix")
      expect(repository.reload.last_error).to be_nil
    end
  end

  describe "#behind_gems" do
    let(:repository) { create(:repository, locked_versions: { "brakeman" => "7.0.0", "rubocop" => "1.80.0" }) }

    before do
      Setting.current.update!(keep_current_gems: %w[brakeman rubocop rails])
      GemRelease.create!(name: "brakeman", version: "8.1.1", checked_at: Time.current)
      GemRelease.create!(name: "rubocop", version: "1.80.0", checked_at: Time.current)
      GemRelease.create!(name: "rails", version: "8.1.4", checked_at: Time.current) # not in this lockfile
    end

    it "lists kept-current gems locked below their latest release" do
      expect(repository.behind_gems).to eq("brakeman" => "8.1.1")
    end

    it "ignores gems that aren't kept current" do
      Setting.current.update!(keep_current_gems: %w[rubocop])

      expect(repository.behind_gems).to eq({})
    end

    it "skips a version declined by closing its PR, until a newer release" do
      closed = create(:fix_pull_request, repository:, state: "closed", closed_at: Time.current)
      create(:gem_bump, repository:, fix_pull_request: closed, gem_name: "brakeman", to_version: "8.1.1")

      expect(repository.behind_gems).to eq({})

      GemRelease.find_by!(name: "brakeman").update!(version: "8.1.2")
      expect(repository.behind_gems).to eq("brakeman" => "8.1.2")
    end
  end
end
