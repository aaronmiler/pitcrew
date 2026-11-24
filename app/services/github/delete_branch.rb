module Github
  # Deletes a Pitcrew branch once its PR is done. Already gone (GitHub's auto-delete on
  # merge, or a person) is fine.
  class DeleteBranch < ApplicationService
    def call(client:, repository:, branch:)
      Github.ensure_pitcrew_branch!(branch)
      client.delete_branch(repository.full_name, branch)
    rescue Octokit::NotFound, Octokit::UnprocessableEntity
      nil
    end
  end
end
