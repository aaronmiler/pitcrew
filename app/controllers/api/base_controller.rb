module Api
  class BaseController < ActionController::API
    # The API authenticates with the session cookie, so it needs CSRF protection.
    # The frontend's js_from_routes client sends X-CSRF-Token from the meta tag.
    include ActionController::RequestForgeryProtection
    protect_from_forgery with: :exception
    # Rails' per-environment setting only reaches ActionController::Base; follow it
    # (on in dev/prod, off in test unless a spec turns it on).
    self.allow_forgery_protection = ActionController::Base.allow_forgery_protection

    include Authentication

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private

    def render_not_found
      render json: { error: "not found" }, status: :not_found
    end
  end
end
