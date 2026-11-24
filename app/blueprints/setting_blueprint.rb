class SettingBlueprint < Blueprinter::Base
  fields :pr_title_template, :tooling_pr_title_template, :allowed_orgs, :keep_current_gems,
    :manual_fix_minutes_low, :manual_fix_minutes_high
  field(:pr_title_fields) { Setting::PR_TITLE_FIELDS }
end
