class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.boolean :singleton, null: false, default: true
      t.string :pr_title_template, null: false,
        default: "chore(security): patch %{advisories} in %{gems}"
      t.string :allowed_orgs, array: true, null: false, default: [] # members may sign in

      t.timestamps
    end
    # One row only: every row has singleton = true, and it must be unique.
    add_index :settings, :singleton, unique: true
  end
end
