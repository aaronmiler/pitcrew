class ServiceIncidentBlueprint < Blueprinter::Base
  identifier :id
  fields :source, :component, :status, :incident_name, :incident_url, :started_at, :resolved_at
end
