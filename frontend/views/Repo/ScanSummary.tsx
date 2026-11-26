import { pluralize, timeAgo } from "../../lib/format"
import type { AdvisoryDbState, LastScan } from "../../types"

// The sync runs every 15 minutes; this long without a check means it's stuck.
const STALE_SYNC_MS = 60 * 60 * 1000

interface IScanSummary {
  scan: LastScan
  advisoryDb: AdvisoryDbState
}

// What the last scan checked, so "nothing outstanding" comes with its evidence.
const ScanSummary = ({ scan, advisoryDb }: IScanSummary) => {
  const syncStale = !advisoryDb.checkedAt || Date.now() - new Date(advisoryDb.checkedAt).getTime() > STALE_SYNC_MS
  // A skipped scan moves only checkedAt; say so when it's meaningfully later than the audit.
  const skippedSince =
    scan.checkedAt &&
    scan.auditedAt &&
    new Date(scan.checkedAt).getTime() - new Date(scan.auditedAt).getTime() > 60 * 1000

  return (
    <div className="card space-y-1 text-sm">
      {scan.auditedAt ? (
        <p>
          {pluralize(scan.gemsChecked ?? 0, "gem")} in <code title={scan.lockfileSha}>Gemfile.lock</code> checked
          against {pluralize(scan.advisoriesChecked ?? 0, "RubyGems advisory", "RubyGems advisories")}{" "}
          <span className="text-muted">
            · audited {timeAgo(scan.auditedAt)}
            {skippedSince && `, last checked ${timeAgo(scan.checkedAt)} (lockfile and advisories unchanged)`}
          </span>
        </p>
      ) : (
        <p className="text-muted">Not audited yet.</p>
      )}
      {scan.ignored && scan.ignored.length > 0 && (
        <p className="text-flag-yellow">
          {pluralize(scan.ignored.length, "advisory", "advisories")} ignored by the repo&apos;s bundler-audit config:{" "}
          {scan.ignored.map((id) => (
            <code key={id} className="mr-1">
              {id}
            </code>
          ))}
        </p>
      )}
      <p className={syncStale ? "text-flag-red" : "text-muted"}>
        Advisory DB checked {timeAgo(advisoryDb.checkedAt)}
        {advisoryDb.committedAt && ` · upstream last changed ${timeAgo(advisoryDb.committedAt)}`}
        {syncStale && " · the sync may be stuck"}
      </p>
    </div>
  )
}

export default ScanSummary
