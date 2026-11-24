import { duration } from "../../lib/format"
import type { Report } from "../../types"

const Exposure = ({ report }: { report: Report }) => {
  const { exposure } = report
  const stages = [
    ["Published → detected", exposure.publishedToDetected, "Advisories published after the repo was added"],
    ["Detected → PR opened", exposure.detectedToPr, null],
    ["PR opened → merged", exposure.prToMerged, null],
    ["Detected → merged", exposure.detectedToMerged, null],
    ["Published → merged", exposure.publishedToMerged, "The full exposure window"],
  ] as const

  return (
    <div className="space-y-3 lg:col-span-2">
      <h2 className="subheading">Exposure window</h2>
      <div className="overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th>Stage</th>
              <th>Median</th>
              <th>Fixes measured</th>
            </tr>
          </thead>
          <tbody>
            {stages.map(([label, stage, note]) => (
              <tr key={label}>
                <td>
                  {label}
                  {note && <div className="text-xs text-muted">{note}</div>}
                </td>
                <td className="font-mono">{duration(stage.median)}</td>
                <td className="text-muted">{stage.count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted">Over findings merged in a Pitcrew PR during the period.</p>
    </div>
  )
}

export default Exposure
