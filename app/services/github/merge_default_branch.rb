module Github
  # Brings an open PR's branch up to date with the default branch, server-side (GitHub's
  # merges API), before Pitcrew works on it. Only when the default branch's Gemfile.lock
  # changed since the branch last took it: that's when the PR's lockfile goes stale and
  # would conflict. Other changes on the default branch are left for people to merge.
  # Returns :current, :skipped (no lockfile change) or :merged; raises Conflict when GitHub
  # can't merge cleanly, so a person resolves it.
  class MergeDefaultBranch < ApplicationService
    Conflict = Class.new(StandardError)
    FILES_LIMIT = 300 # GitHub's compare lists at most this many files

    def call(client:, repository:, branch:)
      Github.ensure_pitcrew_branch!(branch)

      repo = repository.full_name
      default = repository.default_branch
      comparison = client.compare(repo, branch, default) # what the default branch has that the PR branch lacks
      return :current unless %w[ahead diverged].include?(comparison.status)
      return :skipped unless lockfile_changed?(comparison)

      client.merge(repo, branch, default, commit_message: "Merge #{default} into #{branch}")
      :merged
    rescue Octokit::Conflict
      raise Conflict, "Merging #{default} into #{branch} conflicts. Merge it by hand; Pitcrew carries on after that."
    end

    private

    def lockfile_changed?(comparison)
      files = comparison.files.to_a
      files.size >= FILES_LIMIT || files.any? { it.filename == "Gemfile.lock" }
    end
  end
end
