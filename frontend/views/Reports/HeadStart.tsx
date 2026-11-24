import { duration, pluralize } from "../../lib/format"
import type { Report } from "../../types"

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

export default HeadStart
