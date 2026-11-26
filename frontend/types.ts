// js_from_routes camelCases response keys (github_login → githubLogin)
export interface User {
  id: number
  githubLogin: string
  name: string | null
  email: string | null
  accessVia: "direct" | "org"
  pending: boolean
  createdAt: string
}

export interface Settings {
  prTitleTemplate: string
  toolingPrTitleTemplate: string
  allowedOrgs: string[]
  keepCurrentGems: string[]
  prTitleFields: string[]
  manualFixMinutesLow: number
  manualFixMinutesHigh: number
  branchSeparator: string
  branchSeparators: string[]
}

export type FindingStatus = "open" | "in_pr" | "needs_attention" | "resolved"
export type CiStatus = "pending" | "passing" | "failing" | null

export interface PullRequest {
  id: number
  number: number
  state: "open" | "merged" | "closed"
  ciStatus: CiStatus
  branch: string
  openedAt: string
  mergedAt: string | null
  closedAt: string | null
  url: string
}

export interface Advisory {
  id: number
  identifier: string
  packageName: string
  cve: string | null
  ghsa: string | null
  title: string | null
  url: string | null
  criticality: string | null
  patchedVersions: string[]
  publishedOn: string | null
  firstSeenAt: string
  affectedRepositories?: number
}

export interface Finding {
  id: number
  status: FindingStatus
  lockedVersion: string
  reason: string | null
  detectedAt: string
  resolvedAt: string | null
  pullRequestNumber: number | null
  advisory: Advisory
}

export interface FindingEvent {
  id: number
  kind: string
  occurredAt: string
  metadata: Record<string, unknown>
  packageName: string
  advisoryIdentifier: string
}

// What a repo's last scan checked; empty until its first audit since this was recorded.
export interface LastScan {
  checkedAt?: string
  auditedAt?: string
  lockfileSha?: string
  advisoryDbCommit?: string | null
  gemsChecked?: number
  advisoriesChecked?: number
  ignored?: string[]
  detected?: number
  resolved?: number
  open?: number
}

// Where the local ruby-advisory-db checkout stands, from AdvisoryDbSyncJob.
export interface AdvisoryDbState {
  commit: string | null
  committedAt: string | null
  checkedAt: string | null
}

export interface Repository {
  id: number
  fullName: string
  defaultBranch: string
  enabled: boolean
  runtimes: Record<string, string>
  lastScannedAt: string | null
  lastError: string | null
  lastErrorAt: string | null
  lastErrorSource: "scan" | "fix" | null
  ecosystems: string[] | null
  supportedEcosystems: string[]
  resolverConfigured: boolean | null
  rubyMinor: string | null
  lastScan: LastScan
  url: string
}

export interface RepositoryListItem extends Repository {
  findingCounts: { open: number; inPr: number; needsAttention: number }
  openPullRequest: PullRequest | null
}

export interface RepositoryDetail extends Repository {
  resolverMinors: string[]
  resolvedCount: number
  advisoryDb: AdvisoryDbState
  lastErrorIncident: ServiceIncident | null
  findings: Finding[]
  pullRequests: PullRequest[]
  events: FindingEvent[]
}

export interface GemSourceCredential {
  id: number
  host: string
  envKey: string
  updatedAt: string
}

export interface JobFailure {
  jobClass: string
  error: string
  finishedAt: string
  incident: ServiceIncident | null
}

export type ServiceIncidentStatus = "degraded_performance" | "partial_outage" | "major_outage" | "under_maintenance"

// An outage of a GitHub component Pitcrew depends on, from githubstatus.com.
export interface ServiceIncident {
  id: number
  source: string
  component: string
  status: ServiceIncidentStatus
  incidentName: string | null
  incidentUrl: string | null
  startedAt: string
  resolvedAt: string | null
}

export type ResolverStatus = "ok" | "unreachable" | "mismatch" | "missing" | "unknown"

export interface Resolver {
  runtime: string
  minor: string | null
  url: string | null
  status: ResolverStatus
  reported: string | null
  repos: { id: number; fullName: string; enabled: boolean }[]
}

export type ReportRange = "30d" | "90d" | "all"

// Durations are seconds; null when there's nothing to measure.
export interface ReportTotals {
  closed: number
  autoFixed: number
  needsAttention: number
  autoFixRate: number | null
  prsMerged: number
  detectedToMerged: number | null
  minutesSaved: [number, number]
}

export interface ReportStage {
  median: number | null
  count: number
}

export interface ReportWeek {
  weekStart: string
  closed: number
  autoFixed: number
  needsAttention: number
  autoFixRate: number | null
  detectedToMerged: number | null
}

export interface ReportRepo {
  id: number
  fullName: string
  closed: number
  autoFixed: number
  needsAttention: number
  openNow: number
  detectedToMerged: number | null
}

export interface Report {
  range: ReportRange
  since: string | null
  until: string
  reposCovered: number
  totals: ReportTotals
  previous: ReportTotals | null
  exposure: Record<
    "publishedToDetected" | "detectedToPr" | "prToMerged" | "detectedToMerged" | "publishedToMerged",
    ReportStage
  >
  headStart: { median: number | null; count: number; ahead: number; behind: number }
  trend: ReportWeek[]
  repos: ReportRepo[]
}
