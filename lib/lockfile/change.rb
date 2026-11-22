module Lockfile
  # One gem whose locked version differs between two lockfiles.
  class Change
    attr_reader :name, :from, :to

    def initialize(name:, from:, to:)
      @name = name
      @from = from
      @to = to
    end

    def to_s
      "#{name} #{from} → #{to}"
    end
  end
end
