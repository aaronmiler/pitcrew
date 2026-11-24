module Api
  class ReportsController < BaseController
    # ?range=30d|90d|all (anything else: 30d).
    def show
      range = Reports::Summary::RANGES.key?(params[:range]) ? params[:range] : "30d"
      render json: Reports::Summary.call(range:)
    end
  end
end
