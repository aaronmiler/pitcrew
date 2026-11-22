module Github
  # Is `login` a member of `org`? Asked with that org's installation token, so the App
  # must be installed on the org with the "Members: read" permission. If it isn't,
  # the answer is no: access fails closed.
  class OrgMember < ApplicationService
    def call(org:, login:)
      installation = AppClient.call.find_organization_installation(org)
      InstallationClient.call(installation_id: installation.id).organization_member?(org, login)
    rescue Octokit::NotFound, Octokit::Forbidden
      false
    end
  end
end
