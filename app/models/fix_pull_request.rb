class FixPullRequest < ApplicationRecord
  # "pitcrew", one of Setting::BRANCH_SEPARATORS, then a plain branch-safe name. Any
  # separator, not just the current setting, so PRs opened before a change keep working.
  BRANCH_PATTERN = %r{\Apitcrew[/._-][A-Za-z0-9._/-]+\z}

  belongs_to :repository
  has_many :findings, dependent: :nullify
  has_many :gem_bumps, dependent: :destroy

  enum :state, { open: "open", merged: "merged", closed: "closed" }, validate: true
  enum :ci_status, { pending: "pending", passing: "passing", failing: "failing" },
    prefix: :ci, validate: { allow_nil: true }

  validates :number, presence: true, uniqueness: { scope: :repository_id }
  validates :branch, :opened_at, presence: true
  validates :branch, format: { with: BRANCH_PATTERN }
  validate :one_open_per_repository, if: :open?

  # e.g. "pitcrew.security-20261121", or "pitcrew.security-20261121-2" for the repo's second
  # PR that day (the first one's branch may still exist).
  def self.branch_name(repository:, at: Time.current)
    base = "pitcrew#{Setting.current.branch_separator}security-#{at.utc.strftime('%Y%m%d')}"
    taken = repository.fix_pull_requests.where("branch LIKE ?", "#{sanitize_sql_like(base)}%").pluck(:branch)
    return base unless taken.include?(base)

    (2..).lazy.map { "#{base}-#{it}" }.find { !taken.include?(it) }
  end

  private

  # Friendly error; the partial unique index is the race-safe guard.
  def one_open_per_repository
    others = FixPullRequest.open.where(repository_id:).where.not(id:)
    errors.add(:state, "already has an open PR for this repository") if others.exists?
  end
end
