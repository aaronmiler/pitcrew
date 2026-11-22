class AdvisoryBlueprint < Blueprinter::Base
  identifier :id
  fields :package_name, :cve, :ghsa, :title, :url, :criticality, :patched_versions,
    :published_on, :first_seen_at, :source_committed_at, :ghsa_reviewed_at
  field(:identifier) { |advisory| advisory.identifier }

  view :with_affected do
    field(:affected_repositories) { |advisory, options| options[:affected].fetch(advisory.id, 0) }
  end
end
