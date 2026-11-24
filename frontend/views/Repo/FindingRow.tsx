import { FindingStatusBadge } from "../../components/Badge"
import type { Finding } from "../../types"

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

export default FindingRow
