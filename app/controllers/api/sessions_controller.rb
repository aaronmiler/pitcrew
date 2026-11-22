module Api
  # The signed-in user, for the SPA.
  class SessionsController < BaseController
    def show
      render json: UserBlueprint.render(current_user)
    end
  end
end
