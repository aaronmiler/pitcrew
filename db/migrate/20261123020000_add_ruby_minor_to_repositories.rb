class AddRubyMinorToRepositories < ActiveRecord::Migration[8.1]
  # The Ruby minor ("3.4") to resolve with when the repo declares none (no .ruby-version,
  # e.g. a gem). Set in the UI; a declared .ruby-version always wins.
  def change
    add_column :repositories, :ruby_minor, :string
  end
end
