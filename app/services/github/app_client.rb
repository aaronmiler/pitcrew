module Github
  # Octokit client authenticated as the GitHub App itself (a short-lived JWT).
  # Used to list installations and mint installation tokens.
  class AppClient < ApplicationService
    JWT_LIFETIME = 9.minutes # GitHub allows at most 10

    def call
      Octokit::Client.new(bearer_token: jwt, auto_paginate: true)
    end

    private

    def jwt
      now = Time.current.to_i
      payload = { iat: now - 60, exp: now + JWT_LIFETIME.to_i, iss: ENV.fetch("GITHUB_APP_ID") }
      JWT.encode(payload, private_key, "RS256")
    end

    # Accepts the PEM with real newlines or on one line with literal "\n" separators.
    # One line is what survives foreman's .env loader and Docker env files.
    def private_key
      OpenSSL::PKey::RSA.new(ENV.fetch("GITHUB_APP_PRIVATE_KEY").gsub('\n', "\n"))
    rescue OpenSSL::PKey::RSAError
      raise OpenSSL::PKey::RSAError,
        "GITHUB_APP_PRIVATE_KEY isn't a readable PEM. If it's multi-line in .env, foreman and Docker env files " \
        'truncate it: put it on one line with \n between lines.'
    end
  end
end
