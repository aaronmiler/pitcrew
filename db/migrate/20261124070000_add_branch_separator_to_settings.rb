class AddBranchSeparatorToSettings < ActiveRecord::Migration[8.1]
  # The character between "pitcrew" and the rest of a new PR's branch name
  # (pitcrew.security-20261124). One of Setting::BRANCH_SEPARATORS.
  def change
    add_column :settings, :branch_separator, :string, default: ".", null: false
  end
end
