class ReplaceRubyVersionWithRuntimes < ActiveRecord::Migration[8.1]
  # Runtime versions the default branch declares, keyed by runtime: { "ruby" => "3.4.9" }.
  # Ecosystems (bundler, npm, yarn) say which package managers a repo uses; runtimes say
  # which interpreters they need, which is what picks a resolver sidecar.
  def up
    add_column :repositories, :runtimes, :jsonb, default: {}, null: false
    execute <<~SQL.squish
      UPDATE repositories SET runtimes = jsonb_build_object('ruby', ruby_version) WHERE ruby_version IS NOT NULL
    SQL
    remove_column :repositories, :ruby_version
  end

  def down
    add_column :repositories, :ruby_version, :string
    execute "UPDATE repositories SET ruby_version = runtimes->>'ruby'"
    remove_column :repositories, :runtimes
  end
end
