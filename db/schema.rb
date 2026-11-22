# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_22_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "advisories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "criticality"
    t.string "cve"
    t.string "ecosystem", default: "rubygems", null: false
    t.datetime "first_seen_at", null: false
    t.string "ghsa"
    t.datetime "ghsa_published_at"
    t.datetime "ghsa_reviewed_at"
    t.string "package_name", null: false
    t.string "patched_versions", default: [], null: false, array: true
    t.date "published_on"
    t.datetime "source_committed_at"
    t.string "source_id", null: false
    t.string "title"
    t.string "unaffected_versions", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["ecosystem", "package_name", "cve"], name: "index_advisories_on_ecosystem_and_package_name_and_cve", unique: true, where: "(cve IS NOT NULL)"
    t.index ["ecosystem", "package_name", "ghsa"], name: "index_advisories_on_ecosystem_and_package_name_and_ghsa", unique: true, where: "(ghsa IS NOT NULL)"
    t.index ["ecosystem", "package_name", "source_id"], name: "index_advisories_on_ecosystem_and_package_name_and_source_id", unique: true
  end

  create_table "finding_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "finding_id", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finding_id", "occurred_at"], name: "index_finding_events_on_finding_id_and_occurred_at"
    t.index ["kind", "occurred_at"], name: "index_finding_events_on_kind_and_occurred_at"
  end

  create_table "findings", force: :cascade do |t|
    t.bigint "advisory_id", null: false
    t.datetime "created_at", null: false
    t.datetime "detected_at", null: false
    t.bigint "fix_pull_request_id"
    t.string "locked_version", null: false
    t.text "reason"
    t.bigint "repository_id", null: false
    t.datetime "resolved_at"
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["advisory_id"], name: "index_findings_on_advisory_id"
    t.index ["fix_pull_request_id"], name: "index_findings_on_fix_pull_request_id"
    t.index ["repository_id", "advisory_id"], name: "index_findings_on_repository_id_and_advisory_id", unique: true
    t.index ["status"], name: "index_findings_on_status"
  end

  create_table "fix_pull_requests", force: :cascade do |t|
    t.string "branch", null: false
    t.string "ci_status"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.string "head_sha"
    t.datetime "merged_at"
    t.integer "number", null: false
    t.datetime "opened_at", null: false
    t.bigint "repository_id", null: false
    t.string "state", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "number"], name: "index_fix_pull_requests_on_repository_id_and_number", unique: true
    t.index ["repository_id"], name: "index_fix_pull_requests_one_open_per_repository", unique: true, where: "((state)::text = 'open'::text)"
  end

  create_table "gem_bumps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fix_pull_request_id", null: false
    t.string "from_version", null: false
    t.string "gem_name", null: false
    t.bigint "repository_id", null: false
    t.string "to_version", null: false
    t.datetime "updated_at", null: false
    t.index ["fix_pull_request_id", "gem_name"], name: "index_gem_bumps_on_fix_pull_request_id_and_gem_name", unique: true
    t.index ["repository_id"], name: "index_gem_bumps_on_repository_id"
  end

  create_table "gem_releases", force: :cascade do |t|
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["name"], name: "index_gem_releases_on_name", unique: true
  end

  create_table "gem_source_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "host", null: false
    t.text "secret", null: false
    t.datetime "updated_at", null: false
    t.index ["host"], name: "index_gem_source_credentials_on_host", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.integer "lock_type", limit: 2
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main", null: false
    t.string "ecosystems", array: true
    t.boolean "enabled", default: false, null: false
    t.string "full_name", null: false
    t.bigint "github_id", null: false
    t.bigint "installation_id", null: false
    t.text "last_error"
    t.datetime "last_error_at"
    t.string "last_error_source"
    t.datetime "last_scanned_at"
    t.jsonb "locked_versions", default: {}, null: false
    t.string "lockfile_sha"
    t.jsonb "runtimes", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_repositories_on_full_name", unique: true
    t.index ["github_id"], name: "index_repositories_on_github_id", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "allowed_orgs", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.string "keep_current_gems", default: [], null: false, array: true
    t.string "pr_title_template", default: "chore(security): patch %{advisories} in %{gems}", null: false
    t.boolean "singleton", default: true, null: false
    t.string "tooling_pr_title_template", default: "chore(deps): update %{gems}", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton"], name: "index_settings_on_singleton", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "access_via", default: "direct", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "github_login", null: false
    t.bigint "github_uid"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index "lower((github_login)::text)", name: "index_users_on_lower_github_login", unique: true
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true, where: "(github_uid IS NOT NULL)"
  end

  add_foreign_key "finding_events", "findings"
  add_foreign_key "findings", "advisories"
  add_foreign_key "findings", "fix_pull_requests"
  add_foreign_key "findings", "repositories"
  add_foreign_key "fix_pull_requests", "repositories"
  add_foreign_key "gem_bumps", "fix_pull_requests"
  add_foreign_key "gem_bumps", "repositories"
end
