class FindingBlueprint < Blueprinter::Base
  identifier :id
  fields :status, :locked_version, :reason, :detected_at, :resolved_at
  field(:pull_request_number) { |finding| finding.fix_pull_request&.number }
  association :advisory, blueprint: AdvisoryBlueprint
end
