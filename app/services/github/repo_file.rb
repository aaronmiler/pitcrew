module Github
  # One file from a repo's default branch: { sha:, content: }, or nil if it doesn't exist.
  class RepoFile < ApplicationService
    def call(repository:, path:)
      client = InstallationClient.call(installation_id: repository.installation_id)
      file = client.contents(repository.full_name, path:, ref: repository.default_branch)
      { sha: file.sha, content: Base64.decode64(file.content) }
    rescue Octokit::NotFound
      nil
    end
  end
end
