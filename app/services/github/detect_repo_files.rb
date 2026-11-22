module Github
  # What each repo is built on, from a few small files at its root on the default branch,
  # without cloning: one GraphQL query per BATCH repos. Lockfiles are only checked for
  # existence; `.ruby-version` is read (it's a few bytes). Returns
  #   { full_name => { ecosystems: ["bundler", ...], ruby: "3.4.9" or nil } }
  # Repos GitHub couldn't resolve are left out.
  class DetectRepoFiles < ApplicationService
    BATCH = 50
    LOCKFILES = {
      "bundler" => "Gemfile.lock",
      "npm" => "package-lock.json",
      "yarn" => "yarn.lock",
      "pnpm" => "pnpm-lock.yaml"
    }.freeze

    def call(client:, full_names:)
      full_names.each_slice(BATCH).each_with_object({}) do |batch, found|
        data = client.post("graphql", { query: query(batch) }.to_json).to_attrs.fetch(:data, {})
        batch.each_with_index do |full_name, index|
          repo = data[:"r#{index}"] or next
          found[full_name] = {
            ecosystems: LOCKFILES.keys.select { repo[it.to_sym].present? },
            ruby: Repository.ruby_version_from(repo.dig(:ruby_version, :text))
          }
        end
      end
    end

    private

    def query(batch)
      files = LOCKFILES.map { |ecosystem, path| "#{ecosystem}: object(expression: \"HEAD:#{path}\") { ... on Blob { oid } }" }
      files << 'ruby_version: object(expression: "HEAD:.ruby-version") { ... on Blob { text } }'
      fields = batch.each_with_index.map do |full_name, index|
        owner, name = full_name.split("/", 2)
        "r#{index}: repository(owner: #{owner.to_json}, name: #{name.to_json}) { #{files.join(' ')} }"
      end
      "query { #{fields.join(' ')} }"
    end
  end
end
