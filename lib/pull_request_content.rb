# Title (from the Setting templates) and the fixed-format body for a Pitcrew PR.
#   fixed:        [Fix::FixedGem]      gems whose advisories this PR clears
#   companion:    [Lockfile::Change]   lockstep gems moved along, no advisories
#   blocked:      [Fix::Blocked]       advisories needing a human
#   kept_current: [Fix::KeptGem]       kept-current gems; a note when short of latest
# A PR that fixes no advisory, only bumps kept-current gems, uses the tooling title template.
class PullRequestContent
  LIST_LIMIT = 3

  def initialize(repository:, fixed:, companion:, blocked:, kept_current: [])
    @repository = repository
    @fixed = fixed
    @companion = companion
    @blocked = blocked
    @kept_current = kept_current
  end

  # Commit message for an update to an open PR: what this commit adds, since the PR title
  # describes the whole PR. Merges of the default branch are their own commits (GitHub's).
  #   added: [Fix::FixedGem]      gems with advisories new to the PR
  #   bumps: [Lockfile::Change]   kept-current bumps new to the PR
  def self.update_message(added:, bumps:)
    parts = added.map do |gem|
      ids = gem.advisories.size > 2 ? "#{gem.advisories.size} advisories" : gem.advisories.map(&:identifier).join(", ")
      "patch #{ids} in #{gem.name}"
    end
    parts += bumps.map(&:to_s)
    return "Update Gemfile.lock" if parts.empty?

    extra = parts.size > LIST_LIMIT ? " +#{parts.size - LIST_LIMIT} more" : ""
    "Update: #{parts.first(LIST_LIMIT).join('; ')}#{extra}"
  end

  def title
    advisories = @fixed.flat_map(&:advisories).uniq
    gems = (tooling? ? bumped : @fixed).map(&:name)
    Setting.current.render_pr_title(
      tooling: tooling?,
      count: advisories.size,
      advisories: "#{advisories.size} #{'advisory'.pluralize(advisories.size)}",
      gems: truncated(gems),
      gem_count: "#{gems.size} #{'gem'.pluralize(gems.size)}",
      ids: truncated(advisories.map(&:identifier)),
      repo: @repository.full_name,
      date: Date.current.iso8601
    )
  end

  def body
    lines = [intro, ""]

    if @fixed.any?
      lines << "| Gem | From | To | Advisories |"
      lines << "|---|---|---|---|"
      @fixed.each do |gem|
        lines << "| `#{gem.name}` | #{gem.from} | #{gem.to} | #{gem.advisories.map { link(it) }.join(', ')} |"
      end
    end

    if @companion.any?
      lines << ""
      lines << "Updated alongside them, because they're released in lockstep: " \
               "#{@companion.map { "`#{it.name}` #{it.from} → #{it.to}" }.join(', ')}."
    end

    lines.concat(kept_current_section) if @kept_current.any?

    if @blocked.any?
      lines << ""
      lines << "### Needs a manual look"
      lines << ""
      @blocked.each do |blocked|
        finding = blocked.finding
        lines << "- **`#{finding.advisory.package_name}`** #{finding.locked_version}: #{link(finding.advisory)}. #{blocked.reason}"
      end
    end

    lines << ""
    lines << "<sub>Opened by Pitcrew. New advisories and releases update this PR; merge it to unblock `bundle audit`.</sub>"
    lines.join("\n")
  end

  private

  def tooling?
    @fixed.empty?
  end

  def bumped
    @kept_current.select(&:bumped?)
  end

  def intro
    if tooling?
      "Pitcrew updated #{bumped.map { "`#{it.name}`" }.to_sentence} to the latest release by updating " \
        "`Gemfile.lock`. The Gemfile is unchanged."
    else
      count = @fixed.flat_map(&:advisories).uniq.size
      "Pitcrew patched #{count} #{'advisory'.pluralize(count)} by updating `Gemfile.lock`. The Gemfile is unchanged."
    end
  end

  def kept_current_section
    lines = ["", "### Kept current", ""]
    if bumped.any?
      lines << "| Gem | From | To | Latest |"
      lines << "|---|---|---|---|"
      bumped.each { lines << "| `#{it.name}` | #{it.from} | #{it.to} | #{it.latest} |" }
    end
    short = @kept_current.select(&:note)
    lines << "" if bumped.any? && short.any?
    short.each { lines << "- `#{it.name}` #{it.to} is short of the latest, #{it.latest}. #{it.note}" }
    lines
  end

  def link(advisory)
    advisory.url.present? ? "[#{advisory.identifier}](#{advisory.url})" : advisory.identifier
  end

  def truncated(items)
    shown = items.first(LIST_LIMIT).join(", ")
    items.size > LIST_LIMIT ? "#{shown} +#{items.size - LIST_LIMIT} more" : shown
  end
end
