module Lockfile
  # The gems to pass to `bundle lock --update`: the given (vulnerable) gems plus every gem
  # connected to them through exact `(= x)` pins in the lockfile. That keeps lockstep
  # families (Rails, aws-sdk, ...) moving together without a hardcoded list; `--conservative`
  # still holds everything else. Parsing a lockfile doesn't evaluate the Gemfile.
  class Targets < ApplicationService
    def call(content:, gems:)
      links = exact_pin_links(Bundler::LockfileParser.new(content))
      seen = Set.new
      queue = gems.uniq
      while (name = queue.shift)
        next unless seen.add?(name)

        queue.concat(links[name].to_a)
      end
      seen.to_a.sort
    end

    private

    def exact_pin_links(lockfile)
      lockfile.specs.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |spec, links|
        spec.dependencies.each do |dep|
          next unless dep.requirement.requirements.any? { |op, _| op == "=" }

          links[spec.name] << dep.name
          links[dep.name] << spec.name
        end
      end
    end
  end
end
