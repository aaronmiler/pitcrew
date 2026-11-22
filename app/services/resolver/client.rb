module Resolver
  # Talks to the resolver sidecar for a Ruby minor (the Go server in resolver/), which
  # runs Bundler for us: POST /resolve/bundler.
  # Endpoints come from env, like other infrastructure: one variable per sidecar, named
  # RESOLVER_<RUNTIME>_<MAJOR>_<MINOR> (env names can't hold dots):
  #   RESOLVER_RUBY_3_4=http://pitcrew-ruby34:9292
  class Client < ApplicationService
    Unavailable = Class.new(StandardError)

    TIMEOUT = 300 # seconds; a big Rails app resolves in a few
    ENV_PATTERN = /\ARESOLVER_([A-Z]+)_(\d+)_(\d+)\z/

    # { minor => url } for one runtime's sidecars: RESOLVER_RUBY_3_4 -> { "3.4" => url }.
    def self.endpoints(runtime = "ruby")
      ENV.each_with_object({}) do |(key, url), found|
        match = ENV_PATTERN.match(key)
        next unless match && match[1] == runtime.upcase && url.present?

        found["#{match[2]}.#{match[3]}"] = url.strip.delete_suffix("/")
      end
    end

    def self.available?(ruby_minor)
      endpoints.key?(ruby_minor)
    end

    # dir is the checkout's directory name inside the shared work dir.
    def call(ruby_minor:, dir:, gems:, level:, env: {})
      url = self.class.endpoints[ruby_minor] or raise Unavailable, "no resolver for Ruby #{ruby_minor}"

      response = HTTPX.with(timeout: { request_timeout: TIMEOUT })
        .post("#{url}/resolve/bundler", json: { dir:, packages: gems, level: level.to_s, env: })
      raise Unavailable, "resolver for Ruby #{ruby_minor} unreachable: #{response.error.class}" if response.is_a?(HTTPX::ErrorResponse)

      body = JSON.parse(response.body.to_s)
      raise ArgumentError, "resolver rejected the request: #{body['error']}" if response.status == 422
      raise Unavailable, "resolver for Ruby #{ruby_minor} can't run Bundler" if response.status == 404

      Resolver::Result.new(ok: body["ok"], stdout: body["stdout"].to_s, stderr: body["stderr"].to_s)
    end
  end
end
