module AdvisoryDb
  # Clones ruby-advisory-db on first run, fast-forwards it after. Returns the HEAD
  # before and after (before is nil on the first clone). Full history is kept: the
  # importer reads it for when each advisory first landed.
  class Sync < ApplicationService
    def call(path: AdvisoryDb.path, url: AdvisoryDb::REPO_URL)
      if path.join(".git").directory?
        before = head(path)
        Command.run!("git", "pull", "--ff-only", "--quiet", chdir: path)
      else
        before = nil
        FileUtils.mkdir_p(path.dirname)
        Command.run!("git", "clone", "--quiet", url, path)
      end

      { before:, after: head(path) }
    end

    private

    def head(path)
      Command.run!("git", "rev-parse", "HEAD", chdir: path)
    end
  end
end
