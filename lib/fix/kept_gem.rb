module Fix
  # A kept-current gem (Setting.keep_current_gems) that was behind: from the default branch's
  # version to the PR's. note says why it stopped short of latest; nil when it got there.
  class KeptGem
    attr_reader :name, :from, :to, :latest, :note

    def initialize(name:, from:, to:, latest:, note:)
      @name = name
      @from = from
      @to = to
      @latest = latest
      @note = note
    end

    def bumped?
      from != to
    end
  end
end
