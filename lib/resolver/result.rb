module Resolver
  # What a resolver sidecar reported for one `bundle lock` run (Resolver::Client).
  class Result
    attr_reader :ok, :stdout, :stderr

    def initialize(ok:, stdout:, stderr:)
      @ok = ok
      @stdout = stdout
      @stderr = stderr
    end
  end
end
