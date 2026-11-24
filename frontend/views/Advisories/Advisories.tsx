import { useQuery } from "@tanstack/react-query"
import { useState } from "react"

import Badge from "../../components/Badge"
import { timeAgo } from "../../lib/format"
import { apiAdvisories } from "../../lib/routes"
import type { Advisory } from "../../types"

const Advisories = () => {
  const [draft, setDraft] = useState("")
  const [query, setQuery] = useState("")

  const { data: advisories = [], isPending } = useQuery({
    queryKey: ["advisories", query],
    queryFn: () => apiAdvisories.index<Advisory[]>({ query: query ? { q: query } : {} }),
  })

  const handleSearch = (event: React.FormEvent) => {
    event.preventDefault()
    setQuery(draft.trim())
  }

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="heading">Advisories</h1>
        <span className="text-sm text-muted">From ruby-advisory-db, newest published first (up to 100)</span>
        <form onSubmit={handleSearch} className="ml-auto flex gap-2">
          <input
            className="input w-64"
            placeholder="Gem, CVE or GHSA"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
          />
          <button type="submit" className="btn">
            Search
          </button>
        </form>
      </div>

      {isPending ? (
        <p className="text-sm text-muted">Loading…</p>
      ) : advisories.length === 0 ? (
        <p className="text-sm text-muted">No advisories match.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Advisory</th>
              <th>Gem</th>
              <th>Fixed in</th>
              <th>Published</th>
              <th>Affects</th>
            </tr>
          </thead>
          <tbody>
            {advisories.map((advisory) => (
              <tr key={advisory.id}>
                <td>
                  {advisory.url ? (
                    <a href={advisory.url} target="_blank" rel="noreferrer" className="hover:underline">
                      <code>{advisory.identifier}</code>
                    </a>
                  ) : (
                    <code>{advisory.identifier}</code>
                  )}
                  {advisory.criticality && (
                    <span className="ml-1">
                      <Badge
                        tone={advisory.criticality === "critical" || advisory.criticality === "high" ? "red" : "gray"}
                      >
                        {advisory.criticality}
                      </Badge>
                    </span>
                  )}
                  {advisory.title && <div className="text-muted">{advisory.title}</div>}
                </td>
                <td>
                  <code>{advisory.packageName}</code>
                </td>
                <td className="text-muted">
                  {advisory.patchedVersions.length > 0 ? (
                    <code>{advisory.patchedVersions.join(", ")}</code>
                  ) : (
                    "no fix yet"
                  )}
                </td>
                <td className="text-muted">{advisory.publishedOn ?? timeAgo(advisory.firstSeenAt)}</td>
                <td>{advisory.affectedRepositories ? `${advisory.affectedRepositories} repos` : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}

export default Advisories
