Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    repository_inventory: {
      cron: "0 * * * *", # hourly
      class: "RepositoryInventoryJob",
      description: "Mirror the repos the GitHub App can see"
    },
    advisory_db_sync: {
      cron: "*/15 * * * *",
      class: "AdvisoryDbSyncJob",
      description: "Pull ruby-advisory-db, index changes, rescan repos on new advisories"
    },
    pull_request_sync: {
      cron: "*/5 * * * *",
      class: "PullRequestSyncJob",
      description: "Poll open Pitcrew PRs for CI status, merges and closes"
    },
    gem_releases: {
      cron: "30 * * * *", # hourly
      class: "GemReleasesJob",
      description: "Check rubygems.org for new releases of kept-current gems"
    },
    scan_repositories: {
      cron: "7-59/15 * * * *", # offset from the advisory sync
      class: "ScanRepositoriesJob",
      description: "Rescan enabled repos whose Gemfile.lock changed"
    }
  }
end
