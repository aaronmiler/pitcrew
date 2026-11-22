# Temporarily set ENV vars for one example (no gem needed).
module EnvHelpers
  def with_env(vars)
    previous = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # Exactly these resolver sidecars, e.g. with_resolvers("RESOLVER_RUBY_3_4" => url), ignoring
  # any RESOLVER_* a local .env set.
  def with_resolvers(vars, &)
    cleared = ENV.keys.grep(Resolver::Client::ENV_PATTERN).index_with(nil)
    with_env(cleared.merge(vars), &)
  end
end

RSpec.configure { |config| config.include EnvHelpers }
