class PullRequestBlueprint < Blueprinter::Base
  identifier :id
  fields :number, :state, :ci_status, :branch, :opened_at, :merged_at, :closed_at
  field(:url) { |pr| "https://github.com/#{pr.repository.full_name}/pull/#{pr.number}" }
end
