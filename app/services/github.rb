# Pitcrew's GitHub boundary: every call Pitcrew makes to GitHub lives in this namespace,
# one small service per operation. Everything outside it works with Pitcrew's own records
# and the plain values these return (no Octokit resources leak out).
module Github
  # Pitcrew only creates, pushes to, merges into or deletes its own branches (pitcrew/*, or
  # with a . - _ separator). Every write checks first.
  def self.ensure_pitcrew_branch!(branch)
    return if FixPullRequest::BRANCH_PATTERN.match?(branch.to_s)

    raise ArgumentError, "refusing to write #{branch}: Pitcrew only writes its own pitcrew* branches"
  end
end
