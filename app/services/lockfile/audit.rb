require "bundler/audit/scanner" # not loaded by requiring the gem

module Lockfile
  # bundler-audit against the local ruby-advisory-db, for a lockfile's content.
  # Returns Bundler::Audit::Results::UnpatchedGem results (one per gem spec + advisory;
  # platform variants of one gem repeat).
  class Audit < ApplicationService
    CONFIG_PATHS = %w[config/bundler-audit.yml .bundler-audit.yml].freeze

    def self.ignore_list(yaml)
      Array(YAML.safe_load(yaml.to_s)&.dig("ignore"))
    end

    def call(content:, ignore: [])
      Dir.mktmpdir("pitcrew-audit") do |dir|
        File.write(File.join(dir, "Gemfile.lock"), content)
        Bundler::Audit::Scanner.new(dir, "Gemfile.lock", AdvisoryDb.database).scan_specs(ignore:).to_a
      end
    end
  end
end
