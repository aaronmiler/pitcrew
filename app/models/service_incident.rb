class ServiceIncident < ApplicationRecord
  # How often GithubStatusJob polls. We only notice an outage on the next poll, so
  # `started_at` can be up to this late.
  POLL_INTERVAL = 5.minutes

  enum :status, {
    degraded_performance: "degraded_performance",
    partial_outage: "partial_outage",
    major_outage: "major_outage",
    under_maintenance: "under_maintenance"
  }, validate: true

  validates :source, :component, :started_at, presence: true

  scope :open, -> { where(resolved_at: nil) }

  # Incidents that were ongoing at `time`, allowing for the poll delay on `started_at`.
  scope :overlapping, ->(time) {
    where(started_at: ..(time + POLL_INTERVAL)).merge(where(resolved_at: nil).or(where(resolved_at: time..)))
  }

  # The incident (latest started) that was going on at `time`, as a hash for the API;
  # nil when there was none. Lets a failure say "GitHub was degraded at the time".
  def self.at_as_hash(time)
    return unless time

    incident = overlapping(time).order(started_at: :desc).first
    ServiceIncidentBlueprint.render_as_hash(incident) if incident
  end
end
