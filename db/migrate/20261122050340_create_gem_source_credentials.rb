class CreateGemSourceCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :gem_source_credentials do |t|
      t.string :host, null: false
      t.text :secret, null: false # encrypted (Active Record Encryption)

      t.timestamps
    end
    add_index :gem_source_credentials, :host, unique: true
  end
end
