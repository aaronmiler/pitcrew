# Credentials for private gem sources (e.g. rubygems.pkg.github.com), handed to the
# resolver per request as Bundler's BUNDLE_<HOST> env var.
class GemSourceCredential < ApplicationRecord
  encrypts :secret

  normalizes :host, with: ->(host) { host.strip.downcase }

  validates :host, presence: true, uniqueness: true
  validates :secret, presence: true

  # Bundler's env key: dots become "__", dashes "___".
  # rubygems.pkg.github.com -> BUNDLE_RUBYGEMS__PKG__GITHUB__COM
  def env_key
    "BUNDLE_#{host.upcase.gsub('-', '___').gsub('.', '__')}"
  end

  def to_env
    { env_key => secret }
  end

  def inspect
    "#<GemSourceCredential id: #{id.inspect}, host: #{host.inspect}, secret: [FILTERED]>"
  end
end
