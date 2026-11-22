module Fix
  # A finding still flagged after resolving, with a reason a human can act on.
  class Blocked
    attr_reader :finding, :reason

    def initialize(finding:, reason:)
      @finding = finding
      @reason = reason
    end
  end
end
