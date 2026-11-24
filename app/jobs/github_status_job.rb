# Polls githubstatus.com and keeps `service_incidents` in step: a watched component that
# isn't operational opens a row (or updates the open one); one that's operational again
# resolves it. If the status page can't be read, nothing changes: an unreadable page says
# nothing about whether GitHub is up.
class GithubStatusJob < ApplicationJob
  SOURCE = "github".freeze

  def perform
    Github::Status.call.each { record(it) }
  rescue Github::Status::Unavailable => e
    Rails.logger.warn("[GithubStatusJob] status page unavailable: #{e.message}")
  end

  private

  def record(component)
    open = ServiceIncident.open.find_by(source: SOURCE, component: component.name)
    if component.operational?
      open&.update!(resolved_at: Time.current)
    else
      attributes = { status: component.status, incident_name: component.incident_name, incident_url: component.incident_url }
      open ? open.update!(attributes) : ServiceIncident.create!(source: SOURCE, component: component.name, started_at: Time.current, **attributes)
    end
  end
end
