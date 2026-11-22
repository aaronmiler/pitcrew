module LockfileHelpers
  def fixture_lockfile(name)
    Rails.root.join("spec/fixtures/lockfiles/#{name}.lock").read
  end
end

RSpec.configure { |config| config.include LockfileHelpers }
