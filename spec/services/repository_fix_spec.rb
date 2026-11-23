require "rails_helper"

RSpec.describe RepositoryFix do
  let(:repository) { create(:repository, full_name: "aaronmiler/app", runtimes: { "ruby" => "3.4.9" }) }
  let(:rack) { create(:advisory, package_name: "rack", source_id: "CVE-2025-27610", cve: "CVE-2025-27610") }
  let(:session) { create(:advisory, package_name: "rack-session", source_id: "CVE-2025-46336", cve: "CVE-2025-46336") }
  let!(:rack_finding) { create(:finding, repository:, advisory: rack, locked_version: "3.1.0") }
  let!(:session_finding) { create(:finding, repository:, advisory: session, locked_version: "2.0.0") }

  let(:client) { double("octokit") }
  let(:resolver_calls) { [] }
  # What the fake resolver writes for each level; nil = changes nothing (like a failed resolve).
  let(:resolutions) { { patch: "rack_patch_only", minor: "rack_patched" } }
  let(:base_lockfile) { "rack_vulnerable" }
  let(:branch_lockfile) { base_lockfile } # what an open PR's branch holds
  let(:checkouts) { [] }
  let(:branch_ruby_version) { nil } # an open PR's branch's .ruby-version, when it differs

  around do |example|
    Dir.mktmpdir("work") do |work|
      @work = work
      with_resolvers("RESOLVER_RUBY_3_4" => "http://resolver34:9292") do
        with_env("ADVISORY_DB_PATH" => AdvisoryDbHelpers::FIXTURE_DB.to_s, "PITCREW_WORK_DIR" => work) { example.run }
      end
    end
  end

  before do
    allow(Github::InstallationClient).to receive(:call).and_return(client)
    allow(client).to receive_messages(
      create_blob: "blob-sha", create_tree: double(sha: "tree-sha"), create_commit: double(sha: "commit-sha"),
      create_ref: nil, update_ref: nil, create_pull_request: double(number: 7), update_pull_request: nil
    )

    # A real local checkout (of the default branch, or the PR branch), so git status works.
    allow(Github::Checkout).to receive(:call) do |dir:, branch: nil, **|
      checkouts << branch
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\ngem 'rack', '~> 3.1'\ngem 'rack-session'\n")
      File.write(File.join(dir, "Gemfile.lock"), fixture_lockfile(branch ? branch_lockfile : base_lockfile))
      File.write(File.join(dir, ".ruby-version"), "#{branch_ruby_version}\n") if branch && branch_ruby_version
      git(dir, "init", "--quiet")
      git(dir, "add", ".")
      git(dir, "commit", "--quiet", "-m", "base")
      branch ? { head: "pr-head", tree: "pr-tree", token: "ghs_token" } : { head: "default-head", tree: "default-tree", token: "ghs_token" }
    end

    allow(Resolver::Client).to receive(:call) do |ruby_minor:, dir:, gems:, level:, env:|
      resolver_calls << { ruby_minor:, gems:, level:, env: }
      fixture = resolutions[level]
      File.write(File.join(@work, dir, "Gemfile.lock"), fixture_lockfile(fixture)) if fixture
      Resolver::Result.new(ok: true, stdout: "", stderr: "")
    end
  end

  def fix(**)
    described_class.call(repository:, **)
  end

  describe "opening a PR" do
    it "fixes every open finding and opens one PR" do
      result = fix

      expect(result).to eq(result: "pr_opened", pr: 7, fixed: 2, bumped: 0, blocked: 0)
      pr = repository.fix_pull_requests.sole
      expect(pr).to have_attributes(number: 7, state: "open", head_sha: "commit-sha")
      expect(pr.branch).to match(%r{\Apitcrew/security-\d{8}-\d{4}\z})
      expect([rack_finding, session_finding].map { it.reload.status }).to eq(%w[in_pr in_pr])
      expect(FindingEvent.where(kind: "pr_opened").count).to eq(2)
    end

    it "escalates from --patch to --minor only for what --patch didn't fix" do
      fix

      expect(resolver_calls.map { it.slice(:gems, :level) }).to eq([
        { gems: %w[rack rack-session], level: :patch },
        { gems: %w[rack-session], level: :minor }
      ])
    end

    it "stops after --patch when that's enough" do
      resolutions[:patch] = "rack_patched"

      fix

      expect(resolver_calls.map { it[:level] }).to eq([:patch])
    end

    it "commits on the default branch and opens the PR with the rendered title" do
      fix

      expect(client).to have_received(:create_commit)
        .with("aaronmiler/app", "chore(security): patch 2 advisories in rack, rack-session", "tree-sha", ["default-head"])
      expect(client).to have_received(:create_pull_request) do |repo, base, branch, title, body|
        expect([repo, base, title]).to eq(["aaronmiler/app", "main", "chore(security): patch 2 advisories in rack, rack-session"])
        expect(branch).to start_with("pitcrew/security-")
        expect(body).to include("| `rack` | 3.1.0 | 3.1.24 |").and include("| `rack-session` | 2.0.0 | 2.1.2 |")
      end
    end

    it "passes gem source credentials and the installation token to the resolver" do
      create(:gem_source_credential, host: "gems.contribsys.com", secret: "user:pass")

      fix

      expect(resolver_calls.first[:env]).to eq(
        "BUNDLE_GEMS__CONTRIBSYS__COM" => "user:pass", "BUNDLE_GITHUB__COM" => "x-access-token:ghs_token"
      )
    end

    it "cleans up the checkout" do
      fix

      expect(Dir.children(@work)).to be_empty
    end
  end

  describe "what can't be fixed" do
    it "flags everything with a reason when nothing resolves, and opens no PR" do
      resolutions.replace(patch: nil, minor: nil)

      expect(fix).to eq(result: "nothing resolvable", blocked: 2)
      expect(client).not_to have_received(:create_pull_request)
      expect(rack_finding.reload).to have_attributes(
        status: "needs_attention", reason: start_with("The Gemfile requires rack ~> 3.1; the fix needs")
      )
      expect(session_finding.reload.reason).to start_with("No patch or minor release clears it")
    end

    it "opens a PR for what it could fix and lists the rest" do
      resolutions[:minor] = nil

      expect(fix).to include(result: "pr_opened", fixed: 1, blocked: 1)
      expect(session_finding.reload.status).to eq("needs_attention")
      expect(client).to have_received(:create_pull_request) do |*, body|
        expect(body).to include("### Needs a manual look").and include("rack-session")
      end
    end

    it "flags open findings when there's no resolver for the repo's Ruby" do
      repository.update!(runtimes: { "ruby" => "3.2.6" })

      expect(fix).to eq(result: "no resolver")
      expect(rack_finding.reload).to have_attributes(status: "needs_attention", reason: start_with("No resolver for Ruby 3.2"))
      expect(Resolver::Client).not_to have_received(:call)
    end

    it "resolves with the repo's ruby_minor when it declares no Ruby" do
      repository.update!(runtimes: {}, ruby_minor: "3.4")

      fix

      expect(resolver_calls.map { it[:ruby_minor] }.uniq).to eq(["3.4"])
    end

    it "refuses to publish if resolving touched anything but Gemfile.lock" do
      allow(Resolver::Client).to receive(:call) do |dir:, **|
        File.write(File.join(@work, dir, "Gemfile"), "tampered")
        Resolver::Result.new(ok: true, stdout: "", stderr: "")
      end

      expect { fix }.to raise_error(RepositoryFix::UnexpectedChanges, /more than Gemfile\.lock: Gemfile\z/)
      expect(client).not_to have_received(:create_commit)
    end

    it "leaves a declined advisory alone and keeps its reason" do
      session_finding.update!(status: "needs_attention", reason: "PR #3 was closed without merging.")

      fix

      expect(resolver_calls.first[:gems]).to eq(["rack"])
      expect(session_finding.reload.reason).to eq("PR #3 was closed without merging.")
    end
  end

  describe "with an open PR" do
    let!(:pull_request) { create(:fix_pull_request, repository:, number: 7, branch: "pitcrew/security-20261121-1200") }

    before do
      rack_finding.update!(status: "in_pr", fix_pull_request: pull_request)
      allow(client).to receive(:pull_request).and_return(github_pull_request)
      allow(client).to receive(:compare).and_return(double(status: "behind", files: [])) # has the default branch
      allow(client).to receive(:merge)
      allow(Github::RepoFile).to receive(:call).and_return(sha: "lock-sha", content: fixture_lockfile(base_lockfile))
    end

    it "adds new findings on top of the PR branch, so what's on it carries forward" do
      expect(fix).to include(result: "pr_updated", pr: 7, fixed: 2)

      expect(checkouts).to eq(["pitcrew/security-20261121-1200"])
      expect(client).to have_received(:create_tree).with(anything, anything, base_tree: "pr-tree")
      expect(client).to have_received(:create_commit)
        .with("aaronmiler/app", "Update: patch CVE-2025-46336 in rack-session", "tree-sha", ["pr-head"])
      expect(client).to have_received(:update_ref).with("aaronmiler/app", "heads/pitcrew/security-20261121-1200", "commit-sha", false)
      expect(client).to have_received(:update_pull_request).with("aaronmiler/app", 7, title: anything, body: anything)
      expect(session_finding.reload).to have_attributes(status: "in_pr", fix_pull_request: pull_request)
      expect(FindingEvent.where(kind: "pr_updated").map(&:finding)).to eq([session_finding]) # rack was already in it
      expect(pull_request.reload.head_sha).to eq("commit-sha") # the head Pitcrew left
    end

    context "when someone already pushed a fix to the PR branch" do
      let(:branch_lockfile) { "rack_patch_only" } # rack bumped by hand

      it "resolves from their lockfile, and the body still describes the whole PR" do
        fix

        expect(resolver_calls.first[:gems]).to eq(["rack-session"])
        expect(client).to have_received(:update_pull_request) do |*, body:, **|
          expect(body).to include("| `rack` | 3.1.0 | 3.1.24 |").and include("| `rack-session` | 2.0.0 | 2.1.2 |")
        end
      end
    end

    it "merges the default branch in first when its lockfile moved" do
      allow(client).to receive(:compare).and_return(double(status: "diverged", files: [double(filename: "Gemfile.lock")]))

      fix

      expect(client).to have_received(:merge).with("aaronmiler/app", "pitcrew/security-20261121-1200", "main", commit_message: anything)
    end

    it "stops for a person when merging the default branch conflicts" do
      allow(client).to receive(:compare).and_return(double(status: "diverged", files: [double(filename: "Gemfile.lock")]))
      allow(client).to receive(:merge).and_raise(Octokit::Conflict)

      expect { fix }.to raise_error(Github::MergeDefaultBranch::Conflict)
      expect(checkouts).to be_empty
      expect(client).not_to have_received(:create_commit)
    end

    context "when the PR branch is on a newer Ruby than the default branch" do
      let(:branch_ruby_version) { "3.5.0" } # someone's upgrade, not merged yet

      it "resolves with the branch's Ruby" do
        with_resolvers({ "RESOLVER_RUBY_3_4" => "http://resolver34:9292", "RESOLVER_RUBY_3_5" => "http://resolver35:9292" }) { fix }

        expect(resolver_calls.map { it[:ruby_minor] }.uniq).to eq(["3.5"])
        expect(repository.reload.runtimes).to eq("ruby" => "3.4.9") # still the default branch's
      end

      it "stops for a person when there's no resolver for it" do
        expect(fix).to eq(result: "no resolver")
        expect(session_finding.reload).to have_attributes(status: "needs_attention", reason: start_with("No resolver for Ruby 3.5"))
        expect(Resolver::Client).not_to have_received(:call)
      end
    end

    it "leaves it alone when nothing is new, unless forced" do
      session_finding.update!(status: "in_pr", fix_pull_request: pull_request)

      expect(fix).to eq(result: "up to date")
      expect(fix(force: true)).to include(result: "pr_updated")
    end

    it "commits nothing when the branch already has this lockfile, but refreshes the description" do
      session_finding.update!(status: "in_pr", fix_pull_request: pull_request)
      allow(client).to receive(:create_tree).and_return(double(sha: "pr-tree"))

      expect(fix(force: true)).to eq(result: "up to date", pr: 7)
      expect(pull_request.reload.head_sha).to eq("pr-head") # seen, so the poll won't re-trigger
      expect(client).not_to have_received(:create_commit)
      expect(client).to have_received(:update_pull_request).with("aaronmiler/app", 7, title: anything, body: anything)
    end

    it "closes it when the default branch no longer has any of its advisories" do
      [rack_finding, session_finding].each { it.update!(status: "resolved") }
      allow(client).to receive_messages(add_comment: nil, close_pull_request: nil, delete_branch: nil)
      allow(client).to receive(:pull_request).and_return(
        github_pull_request,
        github_pull_request(state: "closed")
      )

      expect(fix).to eq(result: "nothing to fix")
      expect(client).to have_received(:close_pull_request).with("aaronmiler/app", 7)
      expect(pull_request.reload.state).to eq("closed")
    end

    it "opens a fresh PR if the old one was merged in the meantime" do
      allow(client).to receive(:pull_request).and_return(
        github_pull_request(state: "closed", merged: true)
      )
      allow(client).to receive(:delete_branch)
      allow(client).to receive(:create_pull_request).and_return(double(number: 8)) # GitHub never reuses numbers

      result = fix

      expect(pull_request.reload.state).to eq("merged")
      expect(result).to include(result: "pr_opened", pr: 8, fixed: 1) # only the open finding; rack rode the merged PR
      expect(repository.reload.open_fix_pull_request.number).to eq(8)
      expect(rack_finding.reload.fix_pull_request).to eq(pull_request)
    end
  end

  describe "keeping gems current" do
    let(:base_lockfile) { "tooling_patched" }

    before do
      Setting.current.update!(keep_current_gems: ["brakeman"])
      GemRelease.create!(name: "brakeman", version: "8.1.1", checked_at: Time.current)
      repository.update!(locked_versions: Lockfile::Versions.new(fixture_lockfile(base_lockfile)).versions)
      [rack_finding, session_finding].each { it.update!(status: "resolved") }
      resolutions.replace(latest: "tooling_current")
    end

    it "bumps a behind gem with no level flag and opens a PR with the tooling title" do
      expect(fix).to eq(result: "pr_opened", pr: 7, fixed: 0, bumped: 1, blocked: 0)

      expect(resolver_calls.map { it.slice(:gems, :level) }).to eq([{ gems: %w[brakeman], level: :latest }])
      expect(client).to have_received(:create_pull_request) do |*, title, body|
        expect(title).to eq("chore(deps): update brakeman")
        expect(body).to include("### Kept current").and include("| `brakeman` | 7.0.0 | 8.1.1 | 8.1.1 |")
      end
      expect(repository.fix_pull_requests.sole.gem_bumps.sole)
        .to have_attributes(gem_name: "brakeman", from_version: "7.0.0", to_version: "8.1.1")
    end

    context "with advisories to fix too" do
      let(:base_lockfile) { "tooling_behind" }

      it "bumps it in the same PR, under the security title" do
        [rack_finding, session_finding].each { it.update!(status: "open") }
        resolutions.replace(patch: "tooling_patched", latest: "tooling_current")

        expect(fix).to include(result: "pr_opened", fixed: 2, bumped: 1)
        expect(resolver_calls.map { it[:level] }).to eq(%i[patch latest])
        expect(client).to have_received(:create_pull_request) do |*, title, body|
          expect(title).to eq("chore(security): patch 2 advisories in rack, rack-session")
          expect(body).to include("| `brakeman` | 7.0.0 | 8.1.1 | 8.1.1 |")
        end
      end
    end

    it "opens nothing when the gem can't move" do
      resolutions.replace(latest: nil)

      expect(fix).to eq(result: "nothing resolvable", blocked: 0)
      expect(client).not_to have_received(:create_pull_request)
    end

    context "with an open PR whose branch lost the bump (someone rolled it back)" do
      let!(:pull_request) { create(:fix_pull_request, repository:, number: 7, branch: "pitcrew/security-20261121-1200") }

      before do
        create(:gem_bump, repository:, fix_pull_request: pull_request, gem_name: "brakeman", to_version: "8.1.1")
        allow(client).to receive(:pull_request).and_return(github_pull_request(head: "their-head"))
        allow(client).to receive(:compare).and_return(double(status: "behind", files: []))
        allow(Github::RepoFile).to receive(:call).and_return(sha: "lock-sha", content: fixture_lockfile(base_lockfile))
      end

      it "bumps it again and says so, judging by the branch rather than the DB" do
        expect(fix(force: true)).to include(result: "pr_updated", bumped: 1)

        expect(client).to have_received(:create_commit)
          .with("aaronmiler/app", "Update: brakeman 7.0.0 → 8.1.1", "tree-sha", ["pr-head"])
      end
    end

    it "does nothing once the default branch is current" do
      repository.update!(locked_versions: { "brakeman" => "8.1.1" })

      expect(fix).to eq(result: "nothing to fix")
      expect(resolver_calls).to be_empty
    end
  end
end
