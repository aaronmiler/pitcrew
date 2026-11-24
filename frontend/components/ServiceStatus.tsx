import { useQuery } from "@tanstack/react-query"

import { LIVE } from "../lib/refresh"
import { apiServiceIncidents } from "../lib/routes"
import type { ServiceIncident, ServiceIncidentStatus } from "../types"

const STATUS_LABELS: Record<ServiceIncidentStatus, string> = {
  degraded_performance: "degraded performance",
  partial_outage: "partial outage",
  major_outage: "major outage",
  under_maintenance: "under maintenance",
}

const NOTE_PHRASES: Record<ServiceIncidentStatus, string> = {
  degraded_performance: "was degraded",
  partial_outage: "had a partial outage",
  major_outage: "had a major outage",
  under_maintenance: "was under maintenance",
}

// A flag under the header while a GitHub component Pitcrew depends on is having trouble:
// red for a major outage, yellow otherwise. Hidden when everything is operational.
const ServiceStatus = () => {
  const { data: incidents = [] } = useQuery({
    queryKey: ["service_incidents"],
    queryFn: () => apiServiceIncidents.index<ServiceIncident[]>(),
    ...LIVE,
  })

  if (incidents.length === 0) return null

  const major = incidents.some((incident) => incident.status === "major_outage")

  return (
    <div
      role="status"
      className={`border-b ${major ? "border-flag-red/40 bg-flag-red-soft text-flag-red" : "border-flag-yellow/40 bg-flag-yellow-soft text-flag-yellow"}`}
    >
      <ul className="mx-auto max-w-6xl space-y-0.5 px-4 py-2 text-sm">
        {incidents.map((incident) => (
          <li key={incident.id} className="flex flex-wrap items-baseline gap-x-2">
            <span className="text-[11px] font-bold tracking-[0.12em] uppercase">GitHub {incident.component}</span>
            <span>{STATUS_LABELS[incident.status]}</span>
            {incident.incidentName && (
              <a href={incident.incidentUrl ?? undefined} target="_blank" rel="noreferrer" className="underline">
                {incident.incidentName}
              </a>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}

interface IIncidentNote {
  incident: ServiceIncident
}

// Under a failure: GitHub was having trouble when it happened, so it's likely not Pitcrew.
export const IncidentNote = ({ incident }: IIncidentNote) => (
  <div className="mt-1 text-xs">
    GitHub {incident.component} {NOTE_PHRASES[incident.status]} at the time
    {incident.incidentUrl && (
      <>
        {" "}
        (
        <a href={incident.incidentUrl} target="_blank" rel="noreferrer" className="underline">
          {incident.incidentName ?? "incident"}
        </a>
        )
      </>
    )}
    .
  </div>
)

export default ServiceStatus
