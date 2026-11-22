module Api
  # Private gem source credentials. Secrets can be set or replaced, never read back.
  class GemSourceCredentialsController < BaseController
    def index
      render json: GemSourceCredentialBlueprint.render(GemSourceCredential.order(:host))
    end

    def create
      credential = GemSourceCredential.new(params.expect(gem_source_credential: %i[host secret]))
      save(credential, status: :created)
    end

    def update
      credential = GemSourceCredential.find(params[:id])
      credential.assign_attributes(params.expect(gem_source_credential: [:secret]))
      save(credential, status: :ok)
    end

    def destroy
      GemSourceCredential.find(params[:id]).destroy!
      head :no_content
    end

    private

    def save(credential, status:)
      if credential.save
        render json: GemSourceCredentialBlueprint.render(credential), status:
      else
        render json: { errors: credential.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
