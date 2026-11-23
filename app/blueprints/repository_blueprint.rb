class RepositoryBlueprint < Blueprinter::Base
  identifier :id
  fields :full_name, :default_branch, :enabled, :runtimes, :last_scanned_at,
    :last_error, :last_error_at, :last_error_source, :ecosystems, :supported_ecosystems, :ruby_minor
  field(:url) { |repo| "https://github.com/#{repo.full_name}" }
  # Whether a RESOLVER_RUBY_* env var names a sidecar for the repo's Ruby (configured, not pinged);
  # nil when its Ruby is unknown.
  field(:resolver_configured) do |repo|
    minor = repo.runtime_minor(:ruby)
    Resolver::Client.available?(minor) if minor
  end

  # options[:counts]: { [repository_id, status] => n }; options[:open_prs]: { repository_id => FixPullRequest }
  view :list do
    field(:finding_counts) do |repo, options|
      %w[open in_pr needs_attention].index_with { |status| options[:counts].fetch([repo.id, status], 0) }
    end
    field(:open_pull_request) do |repo, options|
      pr = options[:open_prs][repo.id]
      PullRequestBlueprint.render_as_hash(pr) if pr
    end
  end

  view :detail do
    # Configured resolver minors, newest first: the choices for ruby_minor.
    field(:resolver_minors) { Resolver::Client.endpoints.keys.sort_by { Gem::Version.new(it) }.reverse }
    field(:resolved_count) { |repo| repo.findings.resolved.count }
    field(:findings) do |repo|
      FindingBlueprint.render_as_hash(
        repo.findings.where.not(status: "resolved").includes(:advisory, :fix_pull_request).order(:status, :detected_at)
      )
    end
    field(:pull_requests) do |repo|
      PullRequestBlueprint.render_as_hash(repo.fix_pull_requests.includes(:repository).order(opened_at: :desc))
    end
    field(:events) do |repo|
      events = FindingEvent.joins(:finding).where(findings: { repository_id: repo.id })
        .includes(finding: :advisory).order(occurred_at: :desc).limit(50)
      FindingEventBlueprint.render_as_hash(events)
    end
  end
end
