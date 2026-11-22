class Finding < ApplicationRecord
  belongs_to :repository
  belongs_to :advisory
  belongs_to :fix_pull_request, optional: true
  has_many :events, -> { order(:occurred_at) }, class_name: "FindingEvent", dependent: :destroy

  enum :status, {
    open: "open",
    in_pr: "in_pr",
    needs_attention: "needs_attention",
    resolved: "resolved"
  }, validate: true

  validates :locked_version, :detected_at, presence: true
  validates :advisory_id, uniqueness: { scope: :repository_id }

  delegate :ecosystem, to: :advisory

  # State changes. Each appends its event: finding_events is the append-only history value
  # reporting reads, so status never changes without one (or, for repeats, without a reason).

  # Seen in the lockfile: new, or back after being resolved.
  def detect!(locked_version, at: Time.current)
    update!(status: "open", locked_version:, detected_at: at, resolved_at: nil, reason: nil)
    record_event!(:detected, at:, locked_version:)
  end

  # Gone from the lockfile.
  def resolve!(at: Time.current)
    update!(status: "resolved", resolved_at: at)
    record_event!(:resolved, at:)
  end

  # Carried by a Pitcrew PR (kind: :pr_opened or :pr_updated). The event is only for a
  # finding new to this PR; re-publishing the same PR doesn't repeat it.
  def move_to_pr!(pull_request, kind, at: Time.current)
    newly = !in_pr? || fix_pull_request_id != pull_request.id
    update!(status: "in_pr", fix_pull_request: pull_request, reason: nil)
    record_event!(kind, at:, pr: pull_request.number) if newly
  end

  # Needs a human. The reason always updates; the event is only for the change of status.
  def flag!(reason, at: Time.current, **metadata)
    changed = !needs_attention?
    update!(status: "needs_attention", reason:)
    record_event!(:needs_attention, at:, reason:, **metadata) if changed
  end

  # Its PR merged. Status stays in_pr until the next scan sees the new lockfile.
  def merged!(pull_request)
    record_event!(:merged, at: pull_request.merged_at, pr: pull_request.number)
  end

  private

  def record_event!(kind, at:, **metadata)
    events.create!(kind:, occurred_at: at, metadata:)
  end
end
