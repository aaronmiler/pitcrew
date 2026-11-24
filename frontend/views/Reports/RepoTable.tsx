import { Link } from "react-router"

import { duration } from "../../lib/format"
import type { Report } from "../../types"

const RepoTable = ({ report }: { report: Report }) => (
  <div className="space-y-3">
    <h2 className="subheading">By repo</h2>
    {report.repos.length === 0 ? (
      <p className="text-sm text-muted">No enabled repos yet.</p>
    ) : (
      <div className="overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Repo</th>
              <th>Closed</th>
              <th>Auto-fixed</th>
              <th>Needed a person</th>
              <th>Detected → merged</th>
              <th>Open now</th>
            </tr>
          </thead>
          <tbody>
            {report.repos.map((repo) => (
              <tr key={repo.id}>
                <td>
                  <Link to={`/repos/${repo.fullName}`} className="hover:underline">
                    <code>{repo.fullName}</code>
                  </Link>
                </td>
                <td>{repo.closed}</td>
                <td>{repo.autoFixed}</td>
                <td>{repo.needsAttention}</td>
                <td className="font-mono">{duration(repo.detectedToMerged)}</td>
                <td>{repo.openNow}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )}
  </div>
)

export default RepoTable
