import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"
import { Link, useNavigate, useParams } from "react-router"

import Badge, { CiBadge, FindingStatusBadge } from "../../components/Badge"
import { errorMessage, pluralize, timeAgo } from "../../lib/format"
import { apiRepositories } from "../../lib/routes"
import type { Finding, FindingStatus, RepositoryDetail } from "../../types"

const STATUS_ORDER: FindingStatus[] = ["needs_attention", "open", "in_pr"]

const EVENT_LABELS: Record<string, string> = {
  detected: "Detected",
  pr_opened: "PR opened",
  pr_updated: "Added to PR",
  needs_attention: "Needs attention",
  merged: "PR merged",
  resolved: "Resolved",
}

// Served at /repos/:owner/:name. An old /repos/:id link loads by id, then swaps to that URL.
const Repo = () => {
  const { id, owner, name } = useParams()
  const [notice, setNotice] = useState<string | null>(null)

  const {
    data: repo,
    isPending,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["repositories", id ?? `${owner}/${name}`],
    queryFn: () =>
      id
        ? apiRepositories.show<RepositoryDetail>({ params: { id } })
        : apiRepositories.byName<RepositoryDetail>({ params: { owner: owner!, name: name! } }),
  })

  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const scan = useMutation({
    mutationFn: () => apiRepositories.scan({ params: { id: repo!.id } }),
    onSuccess: () => setNotice("Scan queued. Refresh in a moment to see results."),
  })
  const setRubyMinor = useMutation({
    mutationFn: (rubyMinor: string) => apiRepositories.update({ params: { id: repo!.id }, data: { rubyMinor } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["repositories"] }),
  })

  useEffect(() => {
    if (id && repo) navigate(`/repos/${repo.fullName}`, { replace: true })
  }, [id, repo, navigate])

  if (isPending) return <p className="text-sm text-muted">Loading…</p>
  if (!repo) return <p className="text-sm text-muted">Repo not found.</p>

  const findings = [...repo.findings].sort((a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status))

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-start gap-3">
        <div>
          <Link to="/" className="text-sm text-muted hover:underline">
            ← Repos
          </Link>
          <h1 className="heading mt-1">{repo.fullName.split("/").pop()}</h1>
          <a href={repo.url} target="_blank" rel="noreferrer" className="text-sm text-muted hover:underline">
            <code>{repo.fullName}</code>
          </a>
          <p className="text-sm text-muted">
            {repo.enabled ? "Enabled" : "Disabled"} · Ruby {repo.runtimes.ruby ?? "unknown"} · {repo.defaultBranch} ·
            scanned {timeAgo(repo.lastScannedAt)}
          </p>
          <label className="mt-2 flex items-center gap-2 text-sm text-muted">
            Ruby when there&apos;s no .ruby-version
            <select
              className="input"
              value={repo.rubyMinor ?? ""}
              onChange={(e) => setRubyMinor.mutate(e.target.value)}
              disabled={setRubyMinor.isPending}
            >
              <option value="">None (flag fixes)</option>
              {[...new Set([...repo.resolverMinors, ...(repo.rubyMinor ? [repo.rubyMinor] : [])])].map((minor) => (
                <option key={minor} value={minor}>
                  Ruby {minor}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="ml-auto flex gap-2">
          <button type="button" className="btn" onClick={() => refetch()} disabled={isFetching}>
            {isFetching ? "Refreshing…" : "Refresh"}
          </button>
          {repo.enabled && (
            <button type="button" className="btn-primary" onClick={() => scan.mutate()} disabled={scan.isPending}>
              Scan now
            </button>
          )}
        </div>
      </div>

      {repo.lastError && (
        <div className="border border-flag-red/40 bg-flag-red-soft p-3 text-sm text-flag-red">
          <div className="font-medium">
            Last {repo.lastErrorSource} failed {timeAgo(repo.lastErrorAt)}
          </div>
          <div className="font-mono text-xs break-all">{repo.lastError}</div>
        </div>
      )}
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {(scan.error ?? setRubyMinor.error) && (
        <p className="text-sm text-flag-red">{errorMessage(scan.error ?? setRubyMinor.error)}</p>
      )}

      <div className="space-y-2">
        <h2 className="subheading">
          Findings{" "}
          <span className="font-sans text-sm font-normal tracking-normal text-muted normal-case">
            ({pluralize(repo.resolvedCount, "resolved")} hidden)
          </span>
        </h2>
        {findings.length === 0 ? (
          <p className="text-sm text-muted">Nothing outstanding.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Gem</th>
                <th>Advisory</th>
                <th>Locked</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {findings.map((finding) => (
                <FindingRow key={finding.id} finding={finding} />
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="space-y-2">
        <h2 className="subheading">Pull requests</h2>
        {repo.pullRequests.length === 0 ? (
          <p className="text-sm text-muted">None yet.</p>
        ) : (
          <ul className="card space-y-1 text-sm">
            {repo.pullRequests.map((pr) => (
              <li key={pr.id} className="flex items-center gap-2">
                <a href={pr.url} target="_blank" rel="noreferrer" className="font-medium hover:underline">
                  #{pr.number}
                </a>
                <Badge tone={pr.state === "open" ? "blue" : pr.state === "merged" ? "green" : "gray"}>{pr.state}</Badge>
                {pr.state === "open" && <CiBadge status={pr.ciStatus} />}
                <span className="text-muted">
                  opened {timeAgo(pr.openedAt)}
                  {pr.mergedAt && `, merged ${timeAgo(pr.mergedAt)}`}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="space-y-2">
        <h2 className="subheading">Recent activity</h2>
        {repo.events.length === 0 ? (
          <p className="text-sm text-muted">No activity yet.</p>
        ) : (
          <ul className="card space-y-1 text-sm">
            {repo.events.map((event) => (
              <li key={event.id} className="flex gap-2">
                <span className="w-28 shrink-0 text-muted">{timeAgo(event.occurredAt)}</span>
                <span className="w-32 shrink-0">{EVENT_LABELS[event.kind] ?? event.kind}</span>
                <span>
                  <code>{event.packageName}</code> <code className="text-muted">{event.advisoryIdentifier}</code>
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}

interface IFindingRow {
  finding: Finding
}

const FindingRow = ({ finding }: IFindingRow) => (
  <tr>
    <td className="whitespace-nowrap">
      <code>{finding.advisory.packageName}</code>
    </td>
    <td>
      {finding.advisory.url ? (
        <a href={finding.advisory.url} target="_blank" rel="noreferrer" className="hover:underline">
          <code>{finding.advisory.identifier}</code>
        </a>
      ) : (
        <code>{finding.advisory.identifier}</code>
      )}
      {finding.advisory.title && <div className="text-muted">{finding.advisory.title}</div>}
    </td>
    <td>
      <code>{finding.lockedVersion}</code>
    </td>
    <td className="space-y-1">
      <div className="space-x-1">
        <FindingStatusBadge status={finding.status} />
        {finding.pullRequestNumber && <span className="text-muted">#{finding.pullRequestNumber}</span>}
      </div>
      {finding.reason && <div className="text-muted">{finding.reason}</div>}
    </td>
  </tr>
)

export default Repo
