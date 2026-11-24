class AddManualFixMinutesToSettings < ActiveRecord::Migration[8.1]
  # Reports' "time saved" estimate: each auto-fix × the minutes a person would have spent
  # on it, shown as a range (low–high).
  def change
    add_column :settings, :manual_fix_minutes_low, :integer, default: 15, null: false
    add_column :settings, :manual_fix_minutes_high, :integer, default: 30, null: false
  end
end
