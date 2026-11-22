# Session-based sign-in for HTML and API controllers. Everything requires a signed-in
# user unless a controller opts out with `allow_unauthenticated`.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  class_methods do
    def allow_unauthenticated(**)
      skip_before_action(:authenticate!, **)
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def authenticate!
    return if current_user

    if request.format.json?
      render json: { error: "unauthorized" }, status: :unauthorized
    else
      redirect_to sign_in_path
    end
  end

  def start_session_for(user)
    reset_session # avoid session fixation
    session[:user_id] = user.id
  end
end
