import { keepPreviousData, useQuery } from "@tanstack/react-query"
import { useState } from "react"

import { LIVE, useManualRefresh } from "../../lib/refresh"
import { apiReports } from "../../lib/routes"
import type { Report, ReportRange } from "../../types"
import ReportBody from "./ReportBody"
import { RANGES, summaryText } from "./reportFormat"

const Reports = () => {
  const [range, setRange] = useState<ReportRange>("30d")
  const [copied, setCopied] = useState(false)

  const {
    data: report,
    isPending,
    refetch,
  } = useQuery({
    queryKey: ["report", range],
    queryFn: () => apiReports.show<Report>({ query: { range } }),
    placeholderData: keepPreviousData, // switching range keeps the old report up until the new one lands
    ...LIVE,
  })
  const { refresh, refreshing } = useManualRefresh(refetch)

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
          <button type="button" className="btn" onClick={refresh} disabled={refreshing}>
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

export default Reports
