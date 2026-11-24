module Github
  # Commits a new Gemfile.lock through the Git Data API (signed, attributed to the App's
  # bot) on top of `base` (the checkout's head and tree) and points `branch` at it:
  #   - new branch: base is the default branch; the branch is created
  #   - open PR: base is the PR branch's head, so everything already on it (people's commits,
  #     merges of the default branch) carries forward; the ref moves fast-forward only, so a
  #     push that lands mid-run makes this fail instead of being overwritten
  # Only Pitcrew's own refs are ever written. Returns the commit sha, or nil when the PR branch
  # already has exactly this lockfile (nothing to commit).
  class CommitLockfile < ApplicationService
    def call(client:, repository:, branch:, lockfile:, base:, message:, new_branch:)
      Github.ensure_pitcrew_branch!(branch)

      repo = repository.full_name
      blob = client.create_blob(repo, lockfile, "utf-8")
      tree = client.create_tree(repo, [{ path: "Gemfile.lock", mode: "100644", type: "blob", sha: blob }], base_tree: base[:tree])
      return if !new_branch && tree.sha == base[:tree]

      commit = client.create_commit(repo, message, tree.sha, [base[:head]])
      if new_branch
        client.create_ref(repo, "heads/#{branch}", commit.sha)
      else
        client.update_ref(repo, "heads/#{branch}", commit.sha, false)
      end
      commit.sha
    end
  end
end
