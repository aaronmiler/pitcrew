import { useQuery } from "@tanstack/react-query"
import { useState } from "react"
import { Link } from "react-router"

import Sparkline from "../../components/Sparkline"
import { duration, percent, pluralize } from "../../lib/format"
import { apiReports } from "../../lib/routes"
import type { Report, ReportRange, ReportTotals, ReportWeek } from "../../types"

const RANGES: Record<ReportRange, string> = { "30d": "30 days", "90d": "90 days", all: "all time" }

const hours = ([low, high]: [number, number]) => {
  const format = (minutes: number) => (minutes / 60).toFixed(minutes < 600 ? 1 : 0)
  return low === high ? `${format(low)} h` : `${format(low)}–${format(high)} h`
}

const weekLabel = (week: ReportWeek) =>
  new Date(`${week.weekStart}T00:00:00`).toLocaleDateString("en", { month: "short", day: "numeric" })

// Plain text for pasting into Slack or an email.
const summaryText = (report: Report) => {
  const { totals, exposure, headStart } = report
  const period = report.range === "all" ? "All time" : `Last ${RANGES[report.range]}`
  const lines = [
    `Pitcrew, ${period.toLowerCase()}: ${pluralize(totals.closed, "CVE")} closed across ${pluralize(report.repos.filter((repo) => repo.closed > 0).length, "repo")}, ${pluralize(totals.prsMerged, "PR")} merged (${pluralize(report.reposCovered, "repo")} enabled).`,
    `${totals.autoFixed} auto-fixed, ${totals.needsAttention} needed a person (${percent(totals.autoFixRate)} auto-fix rate).`,
  ]
  if (exposure.detectedToMerged.median !== null) {
    lines.push(`Median time from detection to merged fix: ${duration(exposure.detectedToMerged.median)}.`)
  }
  if (exposure.publishedToMerged.median !== null) {
    lines.push(
      `Median time from an advisory's publication to its merged fix: ${duration(exposure.publishedToMerged.median)}.`
    )
  }
  if (headStart.median !== null) {
    lines.push(
      headStart.median >= 0
        ? `GitHub reviewed advisories a median ${duration(headStart.median)} after ruby-advisory-db had them (Dependabot waits for GitHub).`
        : `GitHub reviewed advisories a median ${duration(-headStart.median)} before ruby-advisory-db had them.`
    )
  }
  lines.push(`Estimated time saved: ${hours(totals.minutesSaved)}.`)
  return lines.join("\n")
}

interface IDelta {
  current: number | null
  previous: number | null | undefined
  upIsGood: boolean
  format: (value: number) => string
  period: string
}

// Change vs the previous period: an arrow and the amount, green when it moved the good way.
const Delta = ({ current, previous, upIsGood, format, period }: IDelta) => {
  if (current === null || previous === null || previous === undefined) return null
  const diff = current - previous
  const vs = <span className="font-normal text-muted">vs previous {period}</span>
  if (diff === 0) return <span className="text-xs text-muted">no change {vs}</span>
  const good = diff > 0 === upIsGood
  return (
    <span className={`text-xs font-semibold ${good ? "text-flag-green" : "text-flag-red"}`}>
      {diff > 0 ? "▲" : "▼"} {format(Math.abs(diff))} {vs}
    </span>
  )
}

interface ITile {
  label: string
  value: string
  delta?: React.ReactNode
  values: (number | null)[]
  labels: string[]
}

const Tile = ({ label, value, delta, values, labels }: ITile) => (
  <div className="card flex flex-col gap-2">
    <span className="label">{label}</span>
    <span className="font-display text-[32px] leading-none font-semibold text-ink">{value}</span>
    <span className="min-h-4">{delta}</span>
    <Sparkline values={values} labels={labels} />
    <span className="text-[11px] text-muted">Last 12 weeks</span>
  </div>
)

const Reports = () => {
  const [range, setRange] = useState<ReportRange>("30d")
  const [copied, setCopied] = useState(false)

  const {
    data: report,
    isPending,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["report", range],
    queryFn: () => apiReports.show<Report>({ query: { range } }),
  })

  const handleCopy = async () => {
    if (!report) return
    await navigator.clipboard.writeText(summaryText(report))
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="heading">Reports</h1>
        <span className="text-sm text-muted">CVEs only; kept-current bumps aren&apos;t counted</span>
        <div className="ml-auto flex flex-wrap gap-2">
          <div className="flex" role="group" aria-label="Range">
            {(Object.keys(RANGES) as ReportRange[]).map((key) => (
              <button
                key={key}
                type="button"
                className={`${range === key ? "btn-primary" : "btn"} -ml-px first:ml-0`}
                aria-pressed={range === key}
                onClick={() => setRange(key)}
              >
                {RANGES[key]}
              </button>
            ))}
          </div>
          <button type="button" className="btn" onClick={() => refetch()} disabled={isFetching}>
            Refresh
          </button>
          <button type="button" className="btn" onClick={handleCopy} disabled={!report}>
            {copied ? "Copied" : "Copy summary"}
          </button>
        </div>
      </div>

      {isPending || !report ? <p className="text-sm text-muted">Loading…</p> : <ReportBody report={report} />}
    </section>
  )
}

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

const HeadStart = ({ report }: { report: Report }) => {
  const { headStart } = report
  return (
    <div className="space-y-3">
      <h2 className="subheading">Head start on GitHub</h2>
      <div className="card space-y-2">
        <span className="label">Median lead</span>
        <div className="font-display text-[32px] leading-none font-semibold text-ink">{duration(headStart.median)}</div>
        {headStart.count === 0 ? (
          <p className="text-sm text-muted">No new advisories with GitHub review dates in this period.</p>
        ) : (
          <p className="text-sm">
            Of {pluralize(headStart.count, "new advisory", "new advisories")}, ruby-advisory-db had {headStart.ahead}{" "}
            first; GitHub had {headStart.behind} first.
          </p>
        )}
        <p className="text-xs text-muted">
          Dependabot alerts once GitHub reviews an advisory; Pitcrew acts once ruby-advisory-db has it. Negative means
          GitHub was first.
        </p>
      </div>
    </div>
  )
}

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

export default Reports
