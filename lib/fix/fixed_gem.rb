module Fix
  # A gem whose advisories the PR clears: from the default branch's version to the PR's
  # (to is "removed" when the update dropped it).
  class FixedGem
    attr_reader :name, :from, :to, :advisories

    def initialize(name:, from:, to:, advisories:)
      @name = name
      @from = from
      @to = to
      @advisories = advisories
    end
  end
end
