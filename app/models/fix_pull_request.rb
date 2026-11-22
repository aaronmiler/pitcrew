class FixPullRequest < ApplicationRecord
  BRANCH_PREFIX = "pitcrew/".freeze

  belongs_to :repository
  has_many :findings, dependent: :nullify
  has_many :gem_bumps, dependent: :destroy

  enum :state, { open: "open", merged: "merged", closed: "closed" }, validate: true
  enum :ci_status, { pending: "pending", passing: "passing", failing: "failing" },
    prefix: :ci, validate: { allow_nil: true }

  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :branch, :opened_at, presence: true
  validates :branch, format: { with: /\A#{Regexp.escape(BRANCH_PREFIX)}/ }
  validate :one_open_per_repository, if: :open?

  # e.g. "pitcrew/security-20261121-1432"
  def self.branch_name(at: Time.current)
    "#{BRANCH_PREFIX}security-#{at.utc.strftime('%Y%m%d-%H%M')}"
  end

  private

  # Friendly error; the partial unique index is the race-safe guard.
  def one_open_per_repository
    others = FixPullRequest.open.where(repository_id:).where.not(id:)
    errors.add(:state, "already has an open PR for this repository") if others.exists?
  end
end
