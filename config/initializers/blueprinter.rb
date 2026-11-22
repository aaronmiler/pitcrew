# Serialize with Rails' JSON encoder, not plain JSON: times come out as ISO 8601
# ("2026-11-22T05:43:32.091Z") instead of Time#to_s ("2026-11-22 05:43:32 UTC"),
# which browsers can't reliably parse.
Blueprinter.configure do |config|
  config.generator = ActiveSupport::JSON
  config.method = :encode
end
