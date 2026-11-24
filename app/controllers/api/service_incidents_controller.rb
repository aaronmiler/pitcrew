module Api
  # Outages going on now in the GitHub components Pitcrew depends on (GithubStatusJob).
  class ServiceIncidentsController < BaseController
    def index
      render json: ServiceIncidentBlueprint.render(ServiceIncident.open.order(:component))
    end
  end
end
