import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useState } from "react"
import { Link, useParams } from "react-router"

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

const Repo = () => {
  const { id } = useParams()
  const [notice, setNotice] = useState<string | null>(null)

  const {
    data: repo,
    isPending,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["repositories", id],
    queryFn: () => apiRepositories.show<RepositoryDetail>({ params: { id: id! } }),
  })

  const queryClient = useQueryClient()

  const scan = useMutation({
    mutationFn: () => apiRepositories.scan({ params: { id: id! } }),
    onSuccess: () => setNotice("Scan queued. Refresh in a moment to see results."),
  })
  const setRubyMinor = useMutation({
    mutationFn: (rubyMinor: string) => apiRepositories.update({ params: { id: id! }, data: { rubyMinor } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["repositories"] }),
  })

  if (isPending) return <p className="text-sm text-gray-500">Loading…</p>
  if (!repo) return <p className="text-sm text-gray-500">Repo not found.</p>

  const findings = [...repo.findings].sort((a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status))

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-start gap-3">
        <div>
          <Link to="/" className="text-sm text-gray-500 hover:underline">
            ← Repos
          </Link>
          <h1 className="text-xl font-semibold">
            <a href={repo.url} target="_blank" rel="noreferrer" className="hover:underline">
              {repo.fullName}
            </a>
          </h1>
          <p className="text-sm text-gray-500">
            {repo.enabled ? "Enabled" : "Disabled"} · Ruby {repo.runtimes.ruby ?? "unknown"} · {repo.defaultBranch} ·
            scanned {timeAgo(repo.lastScannedAt)}
          </p>
          <label className="mt-2 flex items-center gap-2 text-sm text-gray-600">
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
            <button type="button" className="btn" onClick={() => scan.mutate()} disabled={scan.isPending}>
              Scan now
            </button>
          )}
        </div>
      </div>

      {repo.lastError && (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-900">
          <div className="font-medium">
            Last {repo.lastErrorSource} failed {timeAgo(repo.lastErrorAt)}
          </div>
          <div className="font-mono text-xs break-all">{repo.lastError}</div>
        </div>
      )}
      {notice && <p className="text-sm text-gray-600">{notice}</p>}
      {(scan.error ?? setRubyMinor.error) && (
        <p className="text-sm text-red-700">{errorMessage(scan.error ?? setRubyMinor.error)}</p>
      )}

      <div className="space-y-2">
        <h2 className="font-semibold">
          Findings{" "}
          <span className="text-sm font-normal text-gray-500">
            ({pluralize(repo.resolvedCount, "resolved")} hidden)
          </span>
        </h2>
        {findings.length === 0 ? (
          <p className="text-sm text-gray-500">Nothing outstanding.</p>
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
        <h2 className="font-semibold">Pull requests</h2>
        {repo.pullRequests.length === 0 ? (
          <p className="text-sm text-gray-500">None yet.</p>
        ) : (
          <ul className="card space-y-1 text-sm">
            {repo.pullRequests.map((pr) => (
              <li key={pr.id} className="flex items-center gap-2">
                <a href={pr.url} target="_blank" rel="noreferrer" className="font-medium hover:underline">
                  #{pr.number}
                </a>
                <Badge tone={pr.state === "open" ? "blue" : pr.state === "merged" ? "green" : "gray"}>{pr.state}</Badge>
                {pr.state === "open" && <CiBadge status={pr.ciStatus} />}
                <span className="text-gray-500">
                  opened {timeAgo(pr.openedAt)}
                  {pr.mergedAt && `, merged ${timeAgo(pr.mergedAt)}`}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="space-y-2">
        <h2 className="font-semibold">Recent activity</h2>
        {repo.events.length === 0 ? (
          <p className="text-sm text-gray-500">No activity yet.</p>
        ) : (
          <ul className="card space-y-1 text-sm">
            {repo.events.map((event) => (
              <li key={event.id} className="flex gap-2">
                <span className="w-28 shrink-0 text-gray-500">{timeAgo(event.occurredAt)}</span>
                <span className="w-32 shrink-0">{EVENT_LABELS[event.kind] ?? event.kind}</span>
                <span>
                  <code>{event.packageName}</code> {event.advisoryIdentifier}
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
    <td>
      <code>{finding.advisory.packageName}</code>
    </td>
    <td>
      {finding.advisory.url ? (
        <a href={finding.advisory.url} target="_blank" rel="noreferrer" className="hover:underline">
          {finding.advisory.identifier}
        </a>
      ) : (
        finding.advisory.identifier
      )}
      {finding.advisory.title && <div className="text-gray-500">{finding.advisory.title}</div>}
    </td>
    <td>{finding.lockedVersion}</td>
    <td className="space-y-1">
      <div className="space-x-1">
        <FindingStatusBadge status={finding.status} />
        {finding.pullRequestNumber && <span className="text-gray-500">#{finding.pullRequestNumber}</span>}
      </div>
      {finding.reason && <div className="text-gray-600">{finding.reason}</div>}
    </td>
  </tr>
)

export default Repo
