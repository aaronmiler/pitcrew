module Fix
  # Runs the resolver sidecar against a checkout: every vulnerable gem (plus its exact-pin
  # family) at --patch, re-audit, --minor for what's left; then kept-current gems still
  # behind, with no level flag (the newest the Gemfile allows). `bundle lock` exits 0 even
  # when it changed nothing, so the re-audit decides, never the exit code.
  # Leaves the result in the checkout and returns the updated Gemfile.lock.
  #   ignore: advisories to leave alone (the repo's ignore list + needs_attention findings)
  #   behind: { gem => latest } kept-current gems behind on the default branch
  #   token:  the installation token, for private github: gem sources
  class Resolve < ApplicationService
    LEVELS = %i[patch minor].freeze

    def call(repository:, dir:, ruby_minor:, ignore:, behind:, token:)
      @repository = repository
      @dir = dir
      @ruby_minor = ruby_minor
      @env = credentials(token)

      LEVELS.each do |level|
        remaining = Lockfile::Audit.call(content: lockfile, ignore:)
        break if remaining.empty?

        run(remaining.map { it.gem.name }, level)
      end
      still_behind = behind_in(lockfile, behind)
      run(still_behind, :latest) if still_behind.any?
      lockfile
    end

    private

    def lockfile
      @dir.join("Gemfile.lock").read
    end

    # One resolver call for the gems plus their exact-pin families.
    def run(gems, level)
      targets = Lockfile::Targets.call(content: lockfile, gems:)
      result = Resolver::Client.call(ruby_minor: @ruby_minor, dir: @dir.basename.to_s, gems: targets, level:, env: @env)
      Rails.logger.warn("[Fix::Resolve] #{@repository.full_name} --#{level}: #{result.stderr.lines.last}") unless result.ok
    end

    def behind_in(content, behind)
      versions = Lockfile::Versions.new(content).versions
      behind.select { |gem, latest| versions[gem] && Gem::Version.new(versions[gem]) < Gem::Version.new(latest) }.keys
    end

    # Gem source credentials, plus the installation token for private github: gem sources.
    def credentials(token)
      env = GemSourceCredential.all.map(&:to_env).reduce({}, :merge)
      env["BUNDLE_GITHUB__COM"] ||= "x-access-token:#{token}"
      env
    end
  end
end
