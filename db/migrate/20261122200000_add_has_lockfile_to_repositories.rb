class AddHasLockfileToRepositories < ActiveRecord::Migration[8.1]
  def change
    # nil until a repo sync has checked; true when the default branch has a root Gemfile.lock.
    add_column :repositories, :has_lockfile, :boolean
  end
end
