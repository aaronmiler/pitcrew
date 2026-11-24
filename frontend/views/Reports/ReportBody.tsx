import { duration, percent, pluralize } from "../../lib/format"
import type { Report, ReportTotals, ReportWeek } from "../../types"
import Exposure from "./Exposure"
import HeadStart from "./HeadStart"
import { hours, RANGES, weekLabel } from "./reportFormat"
import RepoTable from "./RepoTable"
import Tile, { Delta } from "./Tile"
import WeekTable from "./WeekTable"

const ReportBody = ({ report }: { report: Report }) => {
  const { totals, previous, trend } = report
  const period = RANGES[report.range]
  const weeks = trend.map(weekLabel)
  const tip = (format: (week: ReportWeek) => string) =>
    trend.map((week, index) => `Week of ${weeks[index]}: ${format(week)}`)
  const delta = (pick: (t: ReportTotals) => number | null, upIsGood: boolean, format: (value: number) => string) => (
    <Delta
      current={pick(totals)}
      previous={previous && pick(previous)}
      upIsGood={upIsGood}
      format={format}
      period={period}
    />
  )
  const count = (value: number) => String(value)

  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Tile
          label="CVEs closed"
          value={String(totals.closed)}
          delta={delta((t) => t.closed, true, count)}
          values={trend.map((week) => week.closed)}
          labels={tip((week) => `${week.closed} closed`)}
        />
        <Tile
          label="Auto-fix rate"
          value={percent(totals.autoFixRate)}
          delta={delta(
            (t) => t.autoFixRate,
            true,
            (value) => `${Math.round(value * 100)} pts`
          )}
          values={trend.map((week) => week.autoFixRate)}
          labels={tip((week) => `${percent(week.autoFixRate)} (${week.autoFixed} auto, ${week.needsAttention} manual)`)}
        />
        <Tile
          label="Detected → merged"
          value={duration(totals.detectedToMerged)}
          delta={delta((t) => t.detectedToMerged, false, duration)}
          values={trend.map((week) => week.detectedToMerged)}
          labels={tip((week) => `median ${duration(week.detectedToMerged)}`)}
        />
        <Tile
          label="Time saved (est.)"
          value={hours(totals.minutesSaved)}
          delta={delta(
            (t) => t.autoFixed,
            true,
            (value) => pluralize(value, "fix", "fixes")
          )}
          values={trend.map((week) => week.autoFixed)}
          labels={tip((week) => pluralize(week.autoFixed, "auto-fix", "auto-fixes"))}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Exposure report={report} />
        <HeadStart report={report} />
      </div>

      <RepoTable report={report} />
      <WeekTable trend={trend} weeks={weeks} />
    </>
  )
}

export default ReportBody
