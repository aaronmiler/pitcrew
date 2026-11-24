class CreateServiceIncidents < ActiveRecord::Migration[8.1]
  # One row per outage of a service component Pitcrew depends on (GitHub's API Requests,
  # Git Operations, ...), as polled from its status page. Open while `resolved_at` is nil.
  # Kept after resolving, so a failure can say whether GitHub was degraded at the time.
  def change
    create_table :service_incidents do |t|
      t.string :source, null: false
      t.string :component, null: false
      t.string :status, null: false
      t.string :incident_name
      t.string :incident_url
      t.datetime :started_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :service_incidents, %i[started_at resolved_at]
    # At most one open row per component, even if two polls race.
    add_index :service_incidents, %i[source component], unique: true, where: "resolved_at IS NULL",
      name: "index_service_incidents_one_open_per_component"
  end
end
