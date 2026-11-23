module Api
  class RepositoriesController < BaseController
    def index
      supported = Repository.sanitize_sql_array(["ecosystems && ARRAY[?]::varchar[]", Repository::SUPPORTED_ECOSYSTEMS])
      repositories = Repository.order(enabled: :desc).order(Arel.sql("(#{supported}) DESC NULLS LAST")).order(:full_name)
      render json: RepositoryBlueprint.render(
        repositories, view: :list,
        counts: Finding.where.not(status: "resolved").group(:repository_id, :status).count,
        open_prs: FixPullRequest.open.includes(:repository).index_by(&:repository_id)
      )
    end

    def show
      render json: RepositoryBlueprint.render(Repository.find(params[:id]), view: :detail)
    end

    # Only `enabled` and `ruby_minor` are editable. Enabling a repo scans it right away.
    def update
      repository = Repository.find(params[:id])
      attributes = params.expect(repository: %i[enabled ruby_minor])
      attributes[:ruby_minor] = attributes[:ruby_minor].presence if attributes.key?(:ruby_minor)
      return render json: { errors: repository.errors.full_messages }, status: :unprocessable_content unless repository.update(attributes)

      ScanRepositoryJob.perform_later(repository.id, force: true) if repository.enabled? && repository.saved_change_to_enabled?
      render json: RepositoryBlueprint.render(repository)
    end

    def scan
      repository = Repository.find(params[:id])
      return render json: { errors: ["Enable the repo before scanning it."] }, status: :unprocessable_content unless repository.enabled?

      ScanRepositoryJob.perform_later(repository.id, force: true)
      head :accepted
    end

    def sync
      RepositoryInventoryJob.perform_later
      head :accepted
    end
  end
end
