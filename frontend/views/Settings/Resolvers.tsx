import { useQuery } from "@tanstack/react-query"
import { Link } from "react-router"

import Badge from "../../components/Badge"
import { useManualRefresh } from "../../lib/refresh"
import { apiResolvers } from "../../lib/routes"
import type { Resolver, ResolverStatus } from "../../types"

const RUNTIMES: Record<string, string> = { ruby: "Ruby" }

const RESOLVER_STATUS: Record<ResolverStatus, [string, "green" | "red" | "amber" | "gray"]> = {
  ok: ["reachable", "green"],
  unreachable: ["unreachable", "red"],
  mismatch: ["wrong Ruby", "red"],
  missing: ["not configured", "amber"],
  unknown: ["no .ruby-version", "gray"],
}

const resolverHint = (resolver: Resolver) => {
  const enabled = resolver.repos.filter((repo) => repo.enabled).length
  switch (resolver.status) {
    case "missing":
      return enabled > 0 ? "Add a sidecar: these repos can't be fixed." : "Add a sidecar before enabling these repos."
    case "unreachable":
      return "Configured but not answering. Is the sidecar running?"
    case "mismatch":
      return `Answers with Ruby ${resolver.reported}. Check its RESOLVER_RUBY_* env var.`
    case "unknown":
      return "Pitcrew can't tell which Ruby these need. Add a .ruby-version."
    default:
      return resolver.repos.length === 0 ? "No repos need it." : null
  }
}

const Resolvers = () => {
  const {
    data: resolvers = [],
    isPending,
    refetch,
  } = useQuery({
    queryKey: ["resolvers"],
    queryFn: () => apiResolvers.index<Resolver[]>(),
  })
  const { refresh, refreshing } = useManualRefresh(refetch)

  return (
    <div className="card space-y-3">
      <div className="flex items-center gap-3">
        <h2 className="subheading">Resolvers</h2>
        <button type="button" className="btn ml-auto" onClick={refresh} disabled={refreshing}>
          {refreshing ? "Checking…" : "Check again"}
        </button>
      </div>
      <p className="text-sm text-muted">
        One sidecar per Ruby minor resolves lockfiles for the repos on it. To add one, add a service to{" "}
        <code>docker-compose.resolvers.yml</code> (or your stack) and its URL as <code>RESOLVER_RUBY_3_4</code>-style
        env var, then restart Pitcrew.
      </p>

      {isPending ? (
        <p className="text-sm text-muted">Checking…</p>
      ) : resolvers.length === 0 ? (
        <p className="text-sm text-muted">No resolvers configured and no Ruby repos yet.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Runtime</th>
              <th>Status</th>
              <th>Repos</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {resolvers.map((resolver) => {
              const [label, tone] = RESOLVER_STATUS[resolver.status]
              const enabled = resolver.repos.filter((repo) => repo.enabled).length
              return (
                <tr key={`${resolver.runtime}-${resolver.minor ?? "unknown"}`} className="align-top">
                  <td className="font-medium">
                    {RUNTIMES[resolver.runtime] ?? resolver.runtime} {resolver.minor ?? "?"}
                  </td>
                  <td>
                    <Badge tone={tone}>{label}</Badge>
                  </td>
                  <td>
                    {resolver.repos.length > 0 ? (
                      <details>
                        <summary className="cursor-pointer">
                          {enabled} enabled, {resolver.repos.length} total
                        </summary>
                        <ul className="mt-1 space-y-0.5">
                          {[...resolver.repos]
                            .sort((a, b) => Number(b.enabled) - Number(a.enabled))
                            .map((repo) => (
                              <li key={repo.id}>
                                <Link to={`/repos/${repo.fullName}`} className="hover:underline">
                                  <code>{repo.fullName}</code>
                                </Link>
                                {repo.enabled && (
                                  <span className="ml-1">
                                    <Badge tone="blue">enabled</Badge>
                                  </span>
                                )}
                              </li>
                            ))}
                        </ul>
                      </details>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="text-sm text-muted">{resolverHint(resolver)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default Resolvers
