require "bundler/audit/database"
require "bundler/audit/advisory"

# The local ruby-advisory-db checkout: the same data bundle-audit uses, and the
# source of truth for detection. The `advisories` table indexes it.
module AdvisoryDb
  REPO_URL = "https://github.com/rubysec/ruby-advisory-db.git".freeze

  def self.path
    Pathname(ENV.fetch("ADVISORY_DB_PATH", Rails.root.join("storage/ruby-advisory-db").to_s))
  end

  def self.database(path: self.path)
    Bundler::Audit::Database.new(path.to_s)
  end
end
