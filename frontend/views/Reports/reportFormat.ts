import { duration, percent, pluralize } from "../../lib/format"
import type { Report, ReportRange, ReportWeek } from "../../types"

export const RANGES: Record<ReportRange, string> = { "30d": "30 days", "90d": "90 days", all: "all time" }

export const hours = ([low, high]: [number, number]) => {
  const format = (minutes: number) => (minutes / 60).toFixed(minutes < 600 ? 1 : 0)
  return low === high ? `${format(low)} h` : `${format(low)}–${format(high)} h`
}

export const weekLabel = (week: ReportWeek) =>
  new Date(`${week.weekStart}T00:00:00`).toLocaleDateString("en", { month: "short", day: "numeric" })

// Plain text for pasting into Slack or an email.
export const summaryText = (report: Report) => {
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
