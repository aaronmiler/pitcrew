module Github
  # Mirrors every repo the App can see into `repositories`. New repos start disabled;
  # repos the App can no longer see are disabled. Also records each repo's ecosystems and
  # runtimes (from its root files), so the UI can suggest repos to enable and show which
  # resolvers they need. Returns counts for logging.
  class SyncRepositories < ApplicationService
    def call
      seen_ids = []
      created = 0

      AppClient.call.find_app_installations.each do |installation|
        client = InstallationClient.call(installation_id: installation.id)
        repos = client.list_app_installation_repositories.repositories
        detected = DetectRepoFiles.call(client:, full_names: repos.map(&:full_name))
        repos.each do |repo|
          record = Repository.find_or_initialize_by(github_id: repo.id)
          created += 1 if record.new_record?
          record.update!(
            full_name: repo.full_name,
            default_branch: repo.default_branch,
            installation_id: installation.id,
            **detected_attributes(record, detected[repo.full_name])
          )
          seen_ids << repo.id
        end
      end

      disabled = Repository.enabled.where.not(github_id: seen_ids).update_all(enabled: false)
      { seen: seen_ids.size, created:, disabled: }
    end

    private

    # What GitHub couldn't tell us stays as it was.
    def detected_attributes(record, files)
      return {} unless files

      { ecosystems: files[:ecosystems], runtimes: record.with_runtime(:ruby, files[:ruby]) }
    end
  end
end
