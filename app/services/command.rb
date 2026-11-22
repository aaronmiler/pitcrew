require "open3"

# Runs an external command without a shell (argv, so no injection) and returns stdout.
class Command
  Error = Class.new(StandardError)

  def self.run!(*argv, chdir: nil, env: {})
    options = chdir ? { chdir: chdir.to_s } : {} # Open3 rejects chdir: nil
    stdout, stderr, status = Open3.capture3(env, *argv.map(&:to_s), **options)
    # Name only the program and subcommand: later args may carry URLs or tokens.
    raise Error, "#{argv.first(2).join(' ')} failed: #{stderr.strip}" unless status.success?

    stdout.strip
  end
end
