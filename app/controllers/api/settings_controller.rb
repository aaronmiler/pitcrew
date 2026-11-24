module Api
  class SettingsController < BaseController
    def show
      render json: SettingBlueprint.render(Setting.current)
    end

    def update
      setting = Setting.current
      if setting.update(setting_params)
        GemReleasesJob.perform_later if setting.saved_change_to_keep_current_gems?
        render json: SettingBlueprint.render(setting)
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def setting_params
      params.expect(setting: [
        :pr_title_template, :tooling_pr_title_template, :manual_fix_minutes_low, :manual_fix_minutes_high, :branch_separator,
        { allowed_orgs: [], keep_current_gems: [] }
      ])
    end
  end
end
