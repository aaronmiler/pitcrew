import type { CiStatus, FindingStatus, Repository } from "../types"

type Tone = "gray" | "green" | "red" | "amber" | "blue"

const TONES: Record<Tone, string> = {
  gray: "bg-gray-100 text-gray-700",
  green: "bg-green-100 text-green-800",
  red: "bg-red-100 text-red-800",
  amber: "bg-amber-100 text-amber-800",
  blue: "bg-blue-100 text-blue-800",
}

const FINDING: Record<FindingStatus, [string, Tone]> = {
  open: ["open", "red"],
  in_pr: ["in PR", "blue"],
  needs_attention: ["needs attention", "amber"],
  resolved: ["resolved", "green"],
}

const CI: Record<Exclude<CiStatus, null>, [string, Tone]> = {
  pending: ["CI pending", "gray"],
  passing: ["CI passing", "green"],
  failing: ["CI failing", "red"],
}

interface IBadge {
  tone?: Tone
  children: React.ReactNode
}

const Badge = ({ tone = "gray", children }: IBadge) => (
  <span className={`inline-block rounded px-1.5 py-0.5 text-xs font-medium whitespace-nowrap ${TONES[tone]}`}>
    {children}
  </span>
)

export const FindingStatusBadge = ({ status }: { status: FindingStatus }) => {
  const [label, tone] = FINDING[status]
  return <Badge tone={tone}>{label}</Badge>
}

export const CiBadge = ({ status }: { status: CiStatus }) => {
  if (!status) return null
  const [label, tone] = CI[status]
  return <Badge tone={tone}>{label}</Badge>
}

const ECOSYSTEMS: Record<string, string> = { bundler: "Bundler", npm: "npm", yarn: "Yarn", pnpm: "pnpm" }

// A repo's ecosystems; ones Pitcrew can't fix yet are gray. Nothing until a sync has checked.
export const EcosystemBadges = ({ repo }: { repo: Pick<Repository, "ecosystems" | "supportedEcosystems"> }) => {
  if (!repo.ecosystems) return null
  if (repo.ecosystems.length === 0) return <Badge>no lockfile</Badge>
  return (
    <>
      {repo.ecosystems.map((ecosystem) => (
        <Badge key={ecosystem} tone={repo.supportedEcosystems.includes(ecosystem) ? "green" : "gray"}>
          {ECOSYSTEMS[ecosystem] ?? ecosystem}
        </Badge>
      ))}
    </>
  )
}

type RubyRepo = Pick<Repository, "runtimes" | "resolverConfigured" | "rubyMinor">

// The minor that picks the repo's resolver: its .ruby-version's, else the one set in the UI.
export const rubyMinor = (repo: Pick<Repository, "runtimes" | "rubyMinor">) =>
  repo.runtimes.ruby
    ?.replace(/^ruby-/, "")
    .split(".")
    .slice(0, 2)
    .join(".") ?? repo.rubyMinor

// The repo's Ruby (or the minor set for it, when it declares none); amber when no resolver
// is configured for its minor (fixes get flagged).
export const RubyBadge = ({ repo }: { repo: RubyRepo }) => {
  const label = repo.runtimes.ruby ?? (repo.rubyMinor && `${repo.rubyMinor} (set)`)
  if (!label) return null
  if (repo.resolverConfigured === false) {
    return (
      <span title={`No Ruby ${rubyMinor(repo)} resolver: fixes will be flagged until you add one.`}>
        <Badge tone="amber">Ruby {label}</Badge>
      </span>
    )
  }
  return <Badge>Ruby {label}</Badge>
}

export default Badge
