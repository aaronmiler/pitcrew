import { useQuery } from "@tanstack/react-query"

import { timeAgo } from "../lib/format"
import { LIVE } from "../lib/refresh"
import { apiJobFailures } from "../lib/routes"
import type { JobFailure } from "../types"
import { IncidentNote } from "./ServiceStatus"

// Background jobs that failed in the last 24 hours. Hidden when there are none.
const JobFailures = () => {
  const { data: failures = [] } = useQuery({
    queryKey: ["job_failures"],
    queryFn: () => apiJobFailures.index<JobFailure[]>(),
    ...LIVE,
  })

  if (failures.length === 0) return null

  return (
    <details className="border border-flag-red/40 bg-flag-red-soft p-3 text-sm text-flag-red">
      <summary className="cursor-pointer font-medium">
        {failures.length === 1 ? "1 background job" : `${failures.length} background jobs`} failed in the last 24 hours
      </summary>
      <ul className="mt-2 space-y-1">
        {failures.map((failure, index) => (
          <li key={index}>
            <span className="font-medium">{failure.jobClass}</span>{" "}
            <span className="text-flag-red">{timeAgo(failure.finishedAt)}</span>
            <div className="font-mono text-xs break-all">{failure.error}</div>
            {failure.incident && <IncidentNote incident={failure.incident} />}
          </li>
        ))}
      </ul>
    </details>
  )
}

export default JobFailures
