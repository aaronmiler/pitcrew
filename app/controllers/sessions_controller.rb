class SessionsController < ApplicationController
  allow_unauthenticated only: %i[new create failure]
  layout "sessions"

  def new
    redirect_to root_path if current_user
  end

  # GitHub OAuth callback (OmniAuth puts the identity in omniauth.auth).
  def create
    auth = request.env["omniauth.auth"]
    user = Users::SignIn.call(
      uid: auth.uid, login: auth.info.nickname, name: auth.info.name, email: auth.info.email
    )

    if user
      start_session_for(user)
      redirect_to root_path
    else
      redirect_to sign_in_path, alert: "That GitHub account doesn't have access to Pitcrew."
    end
  end

  def failure
    redirect_to sign_in_path, alert: "GitHub sign-in didn't complete. Try again."
  end

  def destroy
    reset_session
    redirect_to sign_in_path
  end
end
