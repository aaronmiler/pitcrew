# Append-only history of a finding. Value reporting is built on it.
class FindingEvent < ApplicationRecord
  belongs_to :finding

  enum :kind, {
    detected: "detected",
    pr_opened: "pr_opened",
    pr_updated: "pr_updated",
    needs_attention: "needs_attention",
    merged: "merged",
    resolved: "resolved"
  }, validate: true

  validates :occurred_at, presence: true

  def readonly?
    persisted?
  end
end
