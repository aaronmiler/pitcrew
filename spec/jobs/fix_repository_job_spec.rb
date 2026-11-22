require "rails_helper"

RSpec.describe FixRepositoryJob, type: :job do
  include ActiveJob::TestHelper

  let(:repository) { create(:repository, enabled: true) }

  it "fixes an enabled repo" do
    allow(RepositoryFix).to receive(:call).and_return(result: "pr_opened")

    described_class.perform_now(repository.id, force: true)

    expect(RepositoryFix).to have_received(:call).with(repository:, force: true)
  end

  it "records a failure on the repo, re-raises it, and clears it after the next success" do
    allow(RepositoryFix).to receive(:call).and_raise(Resolver::Client::Unavailable, "resolver for Ruby 3.4 unreachable")

    expect { described_class.perform_now(repository.id) }.to raise_error(Resolver::Client::Unavailable)
    expect(repository.reload).to have_attributes(last_error_source: "fix", last_error: include("unreachable"))

    allow(RepositoryFix).to receive(:call).and_return(result: "up to date")
    described_class.perform_now(repository.id)
    expect(repository.reload.last_error).to be_nil
  end
end
