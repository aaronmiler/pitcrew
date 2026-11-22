class Advisory < ApplicationRecord
  has_many :findings, dependent: :restrict_with_exception

  enum :ecosystem, { rubygems: "rubygems", npm: "npm" }, validate: true

  validates :package_name, :source_id, :first_seen_at, presence: true
  validates :source_id, uniqueness: { scope: %i[ecosystem package_name] }
  validates :cve, uniqueness: { scope: %i[ecosystem package_name] }, allow_nil: true
  validates :ghsa, uniqueness: { scope: %i[ecosystem package_name] }, allow_nil: true

  # The id people recognize: CVE first, then GHSA, then the source's own id.
  def identifier
    cve.presence || ghsa.presence || source_id
  end
end
