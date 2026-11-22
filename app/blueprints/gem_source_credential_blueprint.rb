# The secret is write-only: never serialized.
class GemSourceCredentialBlueprint < Blueprinter::Base
  identifier :id
  fields :host, :updated_at
  field(:env_key) { |credential| credential.env_key }
end
