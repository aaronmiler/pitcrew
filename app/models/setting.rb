# App-wide settings edited in the UI. A single row; use Setting.current.
# Bootstrap config (DB, encryption keys, GitHub App, PITCREW_INITIAL_USER) stays in env.
class Setting < ApplicationRecord
  PR_TITLE_FIELDS = %i[count advisories gems gem_count ids repo date].freeze
  TITLE_TEMPLATES = %i[pr_title_template tooling_pr_title_template].freeze
  FIELD_PATTERN = /%\{(\w+)\}/
  GEM_NAME = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,100}\z/ # goes into a rubygems.org URL path

  normalizes :allowed_orgs, with: ->(orgs) { orgs.map { it.to_s.strip.downcase }.compact_blank.uniq }
  normalizes :keep_current_gems, with: ->(gems) { gems.map { it.to_s.strip }.compact_blank.uniq }

  validates(*TITLE_TEMPLATES, presence: true)
  validate :title_template_fields_known
  validate :keep_current_gems_are_gem_names

  def self.current
    first_or_create!
  end

  # Only %{field} is special; any other % is literal. Kernel#format is deliberately
  # not used: it treats things like "% p" as directives and renders garbage.
  # tooling: the PR only bumps kept-current gems (no advisories).
  def render_pr_title(tooling: false, **values)
    template = tooling ? tooling_pr_title_template : pr_title_template
    template.gsub(FIELD_PATTERN) { values.fetch(Regexp.last_match(1).to_sym).to_s }
  end

  private

  def title_template_fields_known
    TITLE_TEMPLATES.each do |attribute|
      unknown = self[attribute].to_s.scan(FIELD_PATTERN).flatten.map(&:to_sym) - PR_TITLE_FIELDS
      next if unknown.empty?

      errors.add(attribute, "uses unknown field(s): #{unknown.join(', ')}. Available: #{PR_TITLE_FIELDS.join(', ')}")
    end
  end

  def keep_current_gems_are_gem_names
    invalid = keep_current_gems.grep_v(GEM_NAME)
    errors.add(:keep_current_gems, "has invalid gem name(s): #{invalid.join(', ')}") if invalid.any?
  end
end
