class CreateAdvisories < ActiveRecord::Migration[8.1]
  def change
    create_table :advisories do |t|
      t.string :ecosystem, null: false, default: "rubygems"
      t.string :package_name, null: false
      t.string :source_id, null: false # rubysec file id, e.g. CVE-2025-46336 or GHSA-xxxx
      t.string :cve
      t.string :ghsa
      t.string :title
      t.string :url
      t.string :criticality
      t.string :patched_versions, array: true, null: false, default: []
      t.string :unaffected_versions, array: true, null: false, default: []
      t.date :published_on
      t.datetime :source_committed_at
      t.datetime :ghsa_published_at
      t.datetime :ghsa_reviewed_at
      t.datetime :first_seen_at, null: false

      t.timestamps
    end
    add_index :advisories, %i[ecosystem package_name source_id], unique: true
    # One CVE/GHSA can be filed against several packages, so uniqueness is per package.
    add_index :advisories, %i[ecosystem package_name cve], unique: true, where: "cve IS NOT NULL"
    add_index :advisories, %i[ecosystem package_name ghsa], unique: true, where: "ghsa IS NOT NULL"
  end
end
