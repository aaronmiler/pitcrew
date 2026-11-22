module Lockfile
  # Gem name -> locked version (platform variants collapse to one), and the Gemfile
  # constraints recorded in the lockfile's DEPENDENCIES section.
  class Versions
    def initialize(content)
      @lockfile = Bundler::LockfileParser.new(content)
    end

    def versions
      @versions ||= @lockfile.specs.each_with_object({}) { |spec, map| map[spec.name] ||= spec.version.to_s }
    end

    # The repo's own Gemfile requirement for a direct dependency, e.g. "~> 0.8"; nil if none.
    def gemfile_requirement(name)
      requirement = @lockfile.dependencies[name]&.requirement
      requirement.to_s unless requirement.nil? || requirement.none?
    end

    # Lockfile::Change for each gem whose version changed, by name.
    def self.changes(before, after)
      old, new = Versions.new(before).versions, Versions.new(after).versions
      (old.keys & new.keys).sort.filter_map do |name|
        Change.new(name:, from: old[name], to: new[name]) if old[name] != new[name]
      end
    end
  end
end
