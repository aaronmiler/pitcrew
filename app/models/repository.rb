class Repository < ApplicationRecord
  has_many :findings, dependent: :destroy
  has_many :fix_pull_requests, dependent: :destroy
  has_one :open_fix_pull_request, -> { open }, class_name: "FixPullRequest"
  has_many :gem_bumps, dependent: :destroy

  validates :github_id, presence: true, uniqueness: true
  validates :full_name, presence: true, uniqueness: true
  validates :default_branch, :installation_id, presence: true

  scope :enabled, -> { where(enabled: true) }

  ERROR_SOURCES = %w[scan fix].freeze
  # Ecosystems Pitcrew can fix. Others are detected (Github::DetectRepoFiles) and shown only.
  SUPPORTED_ECOSYSTEMS = %w[bundler].freeze
  RUBY_VERSION_FORMAT = /\A(ruby-)?\d+\.\d+(\.\d+)?([.-]?\w+)?\z/

  # Ecosystems that run on Ruby, for picking which repos need a Ruby resolver.
  RUBY_ECOSYSTEMS = %w[bundler].freeze

  # Merges a runtime's version into runtimes; nil removes it (the file went away).
  def with_runtime(runtime, version)
    runtimes.merge(runtime.to_s => version).compact
  end

  def supported_ecosystems
    (ecosystems || []) & SUPPORTED_ECOSYSTEMS
  end

  # The scan/fix jobs record failures here so the UI can show them. Messages can be long
  # (resolver output), so they're capped.
  def record_error!(source, error)
    update_columns(
      last_error: "#{error.class}: #{error.message}".truncate(1_000),
      last_error_at: Time.current,
      last_error_source: source
    )
  end

  # Clears only an error from the same source, so a skipped scan can't hide a failed fix.
  def clear_error!(source)
    update_columns(last_error: nil, last_error_at: nil, last_error_source: nil) if last_error_source == source
  end

  # Kept-current gems the default branch's lockfile has below their latest release:
  # { "brakeman" => "8.1.1" }. A version declined by closing its PR is skipped until a
  # newer release.
  def behind_gems(names = Setting.current.keep_current_gems)
    declined = gem_bumps.joins(:fix_pull_request).where(fix_pull_requests: { state: "closed" })
      .pluck(:gem_name, :to_version)
    GemRelease.where(name: names).pluck(:name, :version).to_h.select do |name, latest|
      locked = locked_versions[name]
      locked && Gem::Version.new(locked) < Gem::Version.new(latest) && !declined.include?([name, latest])
    end
  end

  # A runtime's minor line, which picks its resolver sidecar: runtimes["ruby"] "3.4.9" -> "3.4".
  def runtime_minor(runtime)
    self.class.minor_of(runtime, runtimes[runtime.to_s])
  end

  def self.minor_of(runtime, version)
    version&.delete_prefix("#{runtime}-")&.split(".")&.first(2)&.join(".")
  end

  # A `.ruby-version` file's version, or nil if it doesn't look like one. Its text comes
  # from the target repo, so anything else (a path, a comment, junk) is ignored.
  def self.ruby_version_from(text)
    version = text.to_s.lines.first.to_s.strip
    version if version.match?(RUBY_VERSION_FORMAT)
  end
end
