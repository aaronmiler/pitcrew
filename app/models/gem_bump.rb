# A kept-current gem moved in a Pitcrew PR (relative to the default branch). Kept apart from
# findings so CVE value reporting stays about CVEs. A bump in a PR closed without merging
# declines that version (see Repository#behind_gems).
class GemBump < ApplicationRecord
  belongs_to :repository
  belongs_to :fix_pull_request

  validates :gem_name, :from_version, :to_version, presence: true
  validates :gem_name, uniqueness: { scope: :fix_pull_request_id }
end
