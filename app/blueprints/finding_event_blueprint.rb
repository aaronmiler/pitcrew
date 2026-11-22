class FindingEventBlueprint < Blueprinter::Base
  identifier :id
  fields :kind, :occurred_at, :metadata
  field(:package_name) { |event| event.finding.advisory.package_name }
  field(:advisory_identifier) { |event| event.finding.advisory.identifier }
end
