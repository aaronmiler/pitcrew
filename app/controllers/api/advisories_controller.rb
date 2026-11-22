module Api
  class AdvisoriesController < BaseController
    LIMIT = 100

    # Newest published first (first_seen_at breaks ties); ?q= matches gem name, CVE or GHSA.
    def index
      advisories = Advisory.order(Arel.sql("published_on DESC NULLS LAST"), first_seen_at: :desc).limit(LIMIT)
      if params[:q].present?
        pattern = "%#{Advisory.sanitize_sql_like(params[:q].strip)}%"
        advisories = advisories.where("package_name ILIKE :pattern OR cve ILIKE :pattern OR ghsa ILIKE :pattern", pattern:)
      end

      affected = Finding.where(advisory_id: advisories.map(&:id)).where.not(status: "resolved")
        .group(:advisory_id).distinct.count(:repository_id)
      render json: AdvisoryBlueprint.render(advisories, view: :with_affected, affected:)
    end
  end
end
