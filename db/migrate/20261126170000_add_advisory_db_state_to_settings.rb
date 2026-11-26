class AddAdvisoryDbStateToSettings < ActiveRecord::Migration[8.1]
  # Where the local ruby-advisory-db checkout stands, written by AdvisoryDbSyncJob on every
  # run (not edited in the UI): the HEAD it's at, when upstream made that commit, and when
  # the job last checked upstream. Lets the UI tell "quiet upstream" from "stuck sync".
  def change
    add_column :settings, :advisory_db_commit, :string
    add_column :settings, :advisory_db_committed_at, :datetime
    add_column :settings, :advisory_db_checked_at, :datetime
  end
end
