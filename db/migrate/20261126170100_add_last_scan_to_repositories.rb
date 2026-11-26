class AddLastScanToRepositories < ActiveRecord::Migration[8.1]
  # What the last scan checked, so a clean result shows its evidence: gems and advisories
  # checked, the lockfile and advisory-db commits, ignored advisories, and the counts.
  # checked_at moves on every scan; audited_at only when the lockfile was actually audited.
  def change
    add_column :repositories, :last_scan, :jsonb, default: {}, null: false
  end
end
