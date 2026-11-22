module Github
  # Octokit client acting as one installation of the App (what opens PRs, reads repos).
  # Installation tokens last an hour; cache them for a little less.
  class InstallationClient < ApplicationService
    TOKEN_CACHE_TTL = 50.minutes

    def call(installation_id:)
      Octokit::Client.new(access_token: token_for(installation_id), auto_paginate: true)
    end

    private

    def token_for(installation_id)
      Rails.cache.fetch("github/installation_token/#{installation_id}", expires_in: TOKEN_CACHE_TTL) do
        AppClient.call.create_app_installation_access_token(installation_id).token
      end
    end
  end
end
