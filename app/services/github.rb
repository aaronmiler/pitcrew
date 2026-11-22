# Pitcrew's GitHub boundary: every call Pitcrew makes to GitHub lives in this namespace,
# one small service per operation. Everything outside it works with Pitcrew's own records
# and the plain values these return (no Octokit resources leak out).
module Github
  # Pitcrew only creates, pushes to, merges into or deletes pitcrew/* branches. Every write
  # checks first.
  def self.ensure_pitcrew_branch!(branch)
    return if branch.to_s.start_with?(FixPullRequest::BRANCH_PREFIX)

    raise ArgumentError, "refusing to write #{branch}: Pitcrew only writes #{FixPullRequest::BRANCH_PREFIX}* branches"
  end
end
