# Everyone who can sign in. A user invited by login has no github_uid until their first
# sign-in; after that they're matched by uid, because logins can be renamed and reclaimed.
class User < ApplicationRecord
  normalizes :github_login, with: ->(login) { login.strip }

  # direct: invited or the initial user, kept until removed.
  # org: allowed via Setting.allowed_orgs, membership re-checked at every sign-in.
  enum :access_via, { direct: "direct", org: "org" }, prefix: :via, validate: true

  validates :github_login, presence: true, uniqueness: { case_sensitive: false }
  validates :github_uid, uniqueness: true, allow_nil: true

  scope :pending, -> { where(github_uid: nil) }

  def self.find_by_login(login)
    find_by("lower(github_login) = ?", login.to_s.strip.downcase)
  end

  def pending?
    github_uid.nil?
  end
end
