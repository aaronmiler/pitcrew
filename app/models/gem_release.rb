# The latest release of each kept-current gem (Setting.keep_current_gems), from rubygems.org.
class GemRelease < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :version, :checked_at, presence: true
end
