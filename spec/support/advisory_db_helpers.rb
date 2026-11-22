# Builds a throwaway git repo shaped like ruby-advisory-db, from spec/fixtures/advisory_db.
module AdvisoryDbHelpers
  FIXTURE_DB = Rails.root.join("spec/fixtures/advisory_db")

  def build_advisory_origin(dir, only: nil)
    origin = Pathname(dir).join("origin")
    files = Dir.glob("gems/*/*.yml", base: FIXTURE_DB)
    files &= only if only
    files.each { |file| copy_fixture(origin, file) }
    git(origin, "init", "--quiet", "--initial-branch=main")
    commit_all(origin, "initial advisories")
    origin
  end

  def add_advisory(origin, relative, from: relative)
    copy_fixture(origin, relative, from:)
    commit_all(origin, "add #{relative}")
  end

  def git(dir, *args)
    Command.run!("git", "-c", "user.name=Spec", "-c", "user.email=spec@example.com", *args, chdir: dir)
  end

  private

  def copy_fixture(origin, relative, from: relative)
    FileUtils.mkdir_p(origin.join(File.dirname(relative)))
    FileUtils.cp(FIXTURE_DB.join(from), origin.join(relative))
  end

  def commit_all(origin, message)
    git(origin, "add", ".")
    git(origin, "commit", "--quiet", "-m", message)
  end
end

RSpec.configure { |config| config.include AdvisoryDbHelpers }
