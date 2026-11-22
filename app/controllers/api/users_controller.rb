module Api
  # Access management: who can sign in. Inviting a login that already has org access
  # makes it a direct user, so it keeps access even if it leaves the org.
  class UsersController < BaseController
    def index
      render json: UserBlueprint.render(User.order(:github_login))
    end

    def create
      user = User.find_by_login(params.expect(:github_login)) || User.new(github_login: params[:github_login])
      user.access_via = "direct"

      if user.save
        render json: UserBlueprint.render(user), status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      user = User.find(params[:id])
      if user == current_user
        render json: { errors: ["You can't remove yourself."] }, status: :unprocessable_content
      else
        user.destroy!
        head :no_content
      end
    end
  end
end
