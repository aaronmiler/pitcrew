module Api
  # Resolver sidecars against what the repos need (Resolver::Status). Read-only: the
  # sidecars are infrastructure, configured as RESOLVER_<RUNTIME>_<MAJOR>_<MINOR> env vars.
  class ResolversController < BaseController
    def index
      render json: Resolver::Status.call
    end
  end
end
