class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :github_uid # nil until an invited user first signs in
      t.string :github_login, null: false
      t.string :name
      t.string :email
      # direct: invited or the initial user, kept until removed.
      # org: allowed via Setting.allowed_orgs, membership re-checked at every sign-in.
      t.string :access_via, null: false, default: "direct"

      t.timestamps
    end
    add_index :users, :github_uid, unique: true, where: "github_uid IS NOT NULL"
    # GitHub logins are case-insensitive.
    add_index :users, "lower(github_login)", unique: true, name: "index_users_on_lower_github_login"
  end
end
