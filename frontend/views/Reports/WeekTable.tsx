import { duration, percent } from "../../lib/format"
import type { ReportWeek } from "../../types"

const WeekTable = ({ trend, weeks }: { trend: ReportWeek[]; weeks: string[] }) => (
  <div className="space-y-3">
    <h2 className="subheading">By week</h2>
    <div className="overflow-x-auto">
      <table className="table">
        <thead>
          <tr>
            <th>Week of</th>
            <th>Closed</th>
            <th>Auto-fixed</th>
            <th>Needed a person</th>
            <th>Auto-fix rate</th>
            <th>Detected → merged</th>
          </tr>
        </thead>
        <tbody>
          {trend
            .map((week, index) => (
              <tr key={week.weekStart}>
                <td>{weeks[index]}</td>
                <td>{week.closed}</td>
                <td>{week.autoFixed}</td>
                <td>{week.needsAttention}</td>
                <td>{percent(week.autoFixRate)}</td>
                <td className="font-mono">{duration(week.detectedToMerged)}</td>
              </tr>
            ))
            .reverse()}
        </tbody>
      </table>
    </div>
  </div>
)

export default WeekTable
