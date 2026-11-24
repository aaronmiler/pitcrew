import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useMemo, useState } from "react"
import { Link } from "react-router"

import Badge, { CiBadge, EcosystemBadges, RubyBadge, rubyMinor } from "../../components/Badge"
import JobFailures from "../../components/JobFailures"
import { errorMessage, timeAgo } from "../../lib/format"
import { apiRepositories } from "../../lib/routes"
import type { RepositoryListItem } from "../../types"

type Filter = "enabled" | "all"

const Repos = () => {
  const [filter, setFilter] = useState<Filter>("enabled")
  const [search, setSearch] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()
  const {
    data: repositories = [],
    isPending,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["repositories"],
    queryFn: () => apiRepositories.index<RepositoryListItem[]>(),
  })

  const visible = useMemo(
    () =>
      repositories.filter(
        (repo) => (filter === "all" || repo.enabled) && repo.fullName.toLowerCase().includes(search.toLowerCase())
      ),
    [repositories, filter, search]
  )
  const enabledCount = repositories.filter((repo) => repo.enabled).length

  const toggle = useMutation({
    mutationFn: (repo: RepositoryListItem) =>
      apiRepositories.update({ params: { id: repo.id }, data: { enabled: !repo.enabled } }),
    onSuccess: (_, repo) => {
      setNotice(
        repo.enabled
          ? `${repo.fullName} disabled.`
          : repo.resolverConfigured === false
            ? `${repo.fullName} enabled; first scan queued. There's no Ruby ${rubyMinor(repo)} resolver yet, so its fixes will be flagged until you add one (Settings → Resolvers).`
            : `${repo.fullName} enabled; first scan queued.`
      )
      queryClient.invalidateQueries({ queryKey: ["repositories"] })
    },
  })
  const scan = useMutation({
    mutationFn: (repo: RepositoryListItem) => apiRepositories.scan({ params: { id: repo.id } }),
    onSuccess: (_, repo) => setNotice(`Scan queued for ${repo.fullName}. Refresh in a moment to see results.`),
  })
  const sync = useMutation({
    mutationFn: () => apiRepositories.sync(),
    onSuccess: () => setNotice("Syncing repos from GitHub. Refresh in a moment."),
  })
  const error = errorMessage(toggle.error ?? scan.error ?? sync.error)

  const handleRefresh = () => {
    refetch()
    queryClient.invalidateQueries({ queryKey: ["job_failures"] })
  }

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="heading">Repos</h1>
        <span className="text-sm text-muted">
          {enabledCount} of {repositories.length} enabled
        </span>
        <div className="ml-auto flex gap-2">
          <button type="button" className="btn" onClick={handleRefresh} disabled={isFetching}>
            {isFetching ? "Refreshing…" : "Refresh"}
          </button>
          <button type="button" className="btn" onClick={() => sync.mutate()} disabled={sync.isPending}>
            Sync repos from GitHub
          </button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-3 text-sm">
        <select className="input" value={filter} onChange={(e) => setFilter(e.target.value as Filter)}>
          <option value="enabled">Enabled</option>
          <option value="all">All repos</option>
        </select>
        <input
          className="input w-64"
          placeholder="Filter by name"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <JobFailures />
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {error && <p className="text-sm text-flag-red">{error}</p>}

      {isPending ? (
        <p className="text-sm text-muted">Loading…</p>
      ) : visible.length === 0 ? (
        <p className="text-sm text-muted">
          {filter === "enabled" ? "No enabled repos yet. Switch to “All repos” to enable some." : "No repos match."}
        </p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Repo</th>
              <th>Enabled</th>
              <th>Findings</th>
              <th>Open PR</th>
              <th>Last scanned</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {visible.map((repo) => (
              <tr
                key={repo.id}
                className={
                  repo.ecosystems && repo.supportedEcosystems.length === 0 && !repo.enabled ? "opacity-50" : undefined
                }
              >
                <td>
                  <Link to={`/repos/${repo.fullName}`} className="font-medium hover:underline">
                    <code>{repo.fullName}</code>
                  </Link>
                  <span className="ml-2 space-x-1">
                    <EcosystemBadges repo={repo} />
                    <RubyBadge repo={repo} />
                  </span>
                </td>
                <td>
                  <input
                    type="checkbox"
                    aria-label={`Enable ${repo.fullName}`}
                    checked={repo.enabled}
                    disabled={toggle.isPending}
                    onChange={() => toggle.mutate(repo)}
                  />
                </td>
                <td className="space-x-1">
                  {repo.findingCounts.open > 0 && <Badge tone="red">{repo.findingCounts.open} open</Badge>}
                  {repo.findingCounts.inPr > 0 && <Badge tone="blue">{repo.findingCounts.inPr} in PR</Badge>}
                  {repo.findingCounts.needsAttention > 0 && (
                    <Badge tone="amber">{repo.findingCounts.needsAttention} need attention</Badge>
                  )}
                </td>
                <td className="space-x-1">
                  {repo.openPullRequest && (
                    <>
                      <a href={repo.openPullRequest.url} className="hover:underline" target="_blank" rel="noreferrer">
                        #{repo.openPullRequest.number}
                      </a>
                      <CiBadge status={repo.openPullRequest.ciStatus} />
                    </>
                  )}
                </td>
                <td className="text-muted">
                  {repo.enabled ? timeAgo(repo.lastScannedAt) : "—"}
                  {repo.lastError && (
                    <div title={repo.lastError}>
                      <Badge tone="red">
                        {repo.lastErrorSource} failed {timeAgo(repo.lastErrorAt)}
                      </Badge>
                    </div>
                  )}
                </td>
                <td className="text-right">
                  {repo.enabled && (
                    <button type="button" className="btn" onClick={() => scan.mutate(repo)} disabled={scan.isPending}>
                      Scan now
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}

export default Repos
