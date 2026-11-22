class AddLastErrorToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :last_error, :text
    add_column :repositories, :last_error_at, :datetime
    add_column :repositories, :last_error_source, :string
  end
end
