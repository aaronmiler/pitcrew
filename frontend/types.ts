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
  url: string
}

export interface RepositoryListItem extends Repository {
  findingCounts: { open: number; inPr: number; needsAttention: number }
  openPullRequest: PullRequest | null
}

export interface RepositoryDetail extends Repository {
  resolverMinors: string[]
  resolvedCount: number
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
