module Fix
  # What a resolve achieved (Fix::Analyze).
  #   fixed:            findings it fixed
  #   blocked:          [Fix::Blocked] findings still flagged, with reasons
  #   kept:             [Fix::KeptGem] kept-current gems that were behind
  #   fixed_gems:       [Fix::FixedGem] the fixed findings, per gem
  #   companion:        [Lockfile::Change] what moved along without advisories of its own
  #   lockfile_changed: whether resolving changed the checkout's lockfile
  #   update_message:   for an open PR, the commit message saying what this update adds
  class Outcome
    attr_reader :fixed, :blocked, :kept, :fixed_gems, :companion, :lockfile_changed, :update_message

    def initialize(fixed:, blocked:, kept:, fixed_gems:, companion:, lockfile_changed:, update_message:)
      @fixed = fixed
      @blocked = blocked
      @kept = kept
      @fixed_gems = fixed_gems
      @companion = companion
      @lockfile_changed = lockfile_changed
      @update_message = update_message
    end

    def bumps
      kept.select(&:bumped?)
    end

    # Nothing worth committing: a new PR whose lockfile didn't move, or no fix and no bump.
    def empty?(new_pr:)
      (new_pr && !lockfile_changed) || (fixed.empty? && bumps.empty?)
    end
  end
end
