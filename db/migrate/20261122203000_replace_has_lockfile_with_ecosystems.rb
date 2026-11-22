class ReplaceHasLockfileWithEcosystems < ActiveRecord::Migration[8.1]
  def change
    remove_column :repositories, :has_lockfile, :boolean
    # Package ecosystems whose lockfile sits at the repo root ("bundler", "npm", ...).
    # nil until a repo sync has checked.
    add_column :repositories, :ecosystems, :string, array: true
  end
end
