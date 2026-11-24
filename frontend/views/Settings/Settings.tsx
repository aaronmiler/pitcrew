import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"
import { Link } from "react-router"

import Badge from "../../components/Badge"
import { errorMessage, timeAgo } from "../../lib/format"
import { apiGemSourceCredentials, apiResolvers, apiSettings } from "../../lib/routes"
import type { GemSourceCredential, Settings as ISettings, Resolver, ResolverStatus } from "../../types"

// Sample values for the live previews (the server renders the real titles).
const date = new Date().toISOString().slice(0, 10)
const SAMPLE: Record<string, string> = {
  count: "3",
  advisories: "3 advisories",
  gems: "rack, rack-session, actionpack +1 more",
  gem_count: "4 gems",
  ids: "CVE-2025-27610, CVE-2025-46336, GHSA-x6mj-8jx9-qhqv +1 more",
  repo: "aaronmiler/app",
  date,
}
const TOOLING_SAMPLE: Record<string, string> = {
  ...SAMPLE,
  count: "0",
  advisories: "0 advisories",
  gems: "brakeman",
  gem_count: "1 gem",
  ids: "",
}

const renderTitle = (template: string, sample: Record<string, string>) =>
  template.replace(/%\{(\w+)\}/g, (match, field) => sample[field] ?? match)

const Settings = () => {
  const [template, setTemplate] = useState("")
  const [toolingTemplate, setToolingTemplate] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()
  const { data: settings } = useQuery({ queryKey: ["settings"], queryFn: () => apiSettings.show<ISettings>() })

  useEffect(() => {
    if (settings) {
      setTemplate(settings.prTitleTemplate)
      setToolingTemplate(settings.toolingPrTitleTemplate)
    }
  }, [settings])

  const save = useMutation({
    mutationFn: () =>
      apiSettings.update({
        data: { setting: { prTitleTemplate: template, toolingPrTitleTemplate: toolingTemplate } },
      }),
    onSuccess: () => {
      setNotice("PR titles saved. They apply to the next PR Pitcrew opens or updates.")
      queryClient.invalidateQueries({ queryKey: ["settings"] })
    },
  })

  const handleSave = (event: React.FormEvent) => {
    event.preventDefault()
    save.mutate()
  }

  return (
    <section className="space-y-6">
      <h1 className="heading">Settings</h1>

      <form onSubmit={handleSave} className="card space-y-3">
        <h2 className="subheading">PR titles</h2>
        <label className="block space-y-1">
          <span className="text-sm font-medium">Security (the PR fixes advisories)</span>
          <input className="input w-full font-mono" value={template} onChange={(e) => setTemplate(e.target.value)} />
          <span className="block text-sm">
            <span className="text-muted">Preview: </span>
            {renderTitle(template, SAMPLE)}
          </span>
        </label>
        <label className="block space-y-1">
          <span className="text-sm font-medium">Kept current only (no advisories)</span>
          <input
            className="input w-full font-mono"
            value={toolingTemplate}
            onChange={(e) => setToolingTemplate(e.target.value)}
          />
          <span className="block text-sm">
            <span className="text-muted">Preview: </span>
            {renderTitle(toolingTemplate, TOOLING_SAMPLE)}
          </span>
        </label>
        <p className="text-sm text-muted">
          Fields:{" "}
          {settings?.prTitleFields.map((field) => (
            <code key={field} className="mr-2">
              %&#123;{field}&#125;
            </code>
          ))}
        </p>
        {notice && <p className="text-sm text-muted">{notice}</p>}
        {save.error && <p className="text-sm text-flag-red">{errorMessage(save.error)}</p>}
        <button type="submit" className="btn-primary" disabled={save.isPending}>
          Save
        </button>
      </form>

      <KeepCurrent settings={settings} />
      <TimeSaved settings={settings} />
      <Resolvers />
      <Credentials />
    </section>
  )
}

const KeepCurrent = ({ settings }: { settings: ISettings | undefined }) => {
  const [gems, setGems] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()

  useEffect(() => {
    if (settings) setGems(settings.keepCurrentGems.join(", "))
  }, [settings])

  const save = useMutation({
    mutationFn: () =>
      apiSettings.update({ data: { setting: { keepCurrentGems: gems.split(",").map((gem) => gem.trim()) } } }),
    onSuccess: () => {
      setNotice("Saved. Pitcrew checks rubygems.org now, then hourly.")
      queryClient.invalidateQueries({ queryKey: ["settings"] })
    },
  })

  const handleSave = (event: React.FormEvent) => {
    event.preventDefault()
    save.mutate()
  }

  return (
    <form onSubmit={handleSave} className="card space-y-3">
      <h2 className="subheading">Keep current</h2>
      <p className="text-sm text-muted">
        Gems kept at their latest release, e.g. <code>brakeman</code> (its <code>--ensure-latest</code> fails CI the day
        a release ships). Bumps ride along in each repo&apos;s Pitcrew PR. Comma-separated.
      </p>
      <input className="input w-full font-mono" value={gems} onChange={(e) => setGems(e.target.value)} />
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {save.error && <p className="text-sm text-flag-red">{errorMessage(save.error)}</p>}
      <button type="submit" className="btn-primary" disabled={save.isPending}>
        Save
      </button>
    </form>
  )
}

const TimeSaved = ({ settings }: { settings: ISettings | undefined }) => {
  const [low, setLow] = useState("")
  const [high, setHigh] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()

  useEffect(() => {
    if (settings) {
      setLow(String(settings.manualFixMinutesLow))
      setHigh(String(settings.manualFixMinutesHigh))
    }
  }, [settings])

  const save = useMutation({
    mutationFn: () =>
      apiSettings.update({
        data: { setting: { manualFixMinutesLow: Number(low), manualFixMinutesHigh: Number(high) } },
      }),
    onSuccess: () => {
      setNotice("Saved.")
      queryClient.invalidateQueries({ queryKey: ["settings"] })
      queryClient.invalidateQueries({ queryKey: ["report"] })
    },
  })

  const handleSave = (event: React.FormEvent) => {
    event.preventDefault()
    save.mutate()
  }

  return (
    <form onSubmit={handleSave} className="card space-y-3">
      <h2 className="subheading">Time saved estimate</h2>
      <p className="text-sm text-muted">
        Minutes a person would spend on one fix by hand. Reports multiply each auto-fix by this range.
      </p>
      <div className="flex items-center gap-2 text-sm">
        <input
          type="number"
          min={1}
          className="input w-20"
          aria-label="Low estimate (minutes)"
          value={low}
          onChange={(e) => setLow(e.target.value)}
        />
        <span>to</span>
        <input
          type="number"
          min={1}
          className="input w-20"
          aria-label="High estimate (minutes)"
          value={high}
          onChange={(e) => setHigh(e.target.value)}
        />
        <span>minutes per fix</span>
      </div>
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {save.error && <p className="text-sm text-flag-red">{errorMessage(save.error)}</p>}
      <button type="submit" className="btn-primary" disabled={save.isPending}>
        Save
      </button>
    </form>
  )
}

const RUNTIMES: Record<string, string> = { ruby: "Ruby" }

const RESOLVER_STATUS: Record<ResolverStatus, [string, "green" | "red" | "amber" | "gray"]> = {
  ok: ["reachable", "green"],
  unreachable: ["unreachable", "red"],
  mismatch: ["wrong Ruby", "red"],
  missing: ["not configured", "amber"],
  unknown: ["no .ruby-version", "gray"],
}

const resolverHint = (resolver: Resolver) => {
  const enabled = resolver.repos.filter((repo) => repo.enabled).length
  switch (resolver.status) {
    case "missing":
      return enabled > 0 ? "Add a sidecar: these repos can't be fixed." : "Add a sidecar before enabling these repos."
    case "unreachable":
      return "Configured but not answering. Is the sidecar running?"
    case "mismatch":
      return `Answers with Ruby ${resolver.reported}. Check its RESOLVER_RUBY_* env var.`
    case "unknown":
      return "Pitcrew can't tell which Ruby these need. Add a .ruby-version."
    default:
      return resolver.repos.length === 0 ? "No repos need it." : null
  }
}

const Resolvers = () => {
  const {
    data: resolvers = [],
    isPending,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["resolvers"],
    queryFn: () => apiResolvers.index<Resolver[]>(),
  })

  return (
    <div className="card space-y-3">
      <div className="flex items-center gap-3">
        <h2 className="subheading">Resolvers</h2>
        <button type="button" className="btn ml-auto" onClick={() => refetch()} disabled={isFetching}>
          {isFetching ? "Checking…" : "Check again"}
        </button>
      </div>
      <p className="text-sm text-muted">
        One sidecar per Ruby minor resolves lockfiles for the repos on it. To add one, add a service to{" "}
        <code>docker-compose.resolvers.yml</code> (or your stack) and its URL as <code>RESOLVER_RUBY_3_4</code>-style
        env var, then restart Pitcrew.
      </p>

      {isPending ? (
        <p className="text-sm text-muted">Checking…</p>
      ) : resolvers.length === 0 ? (
        <p className="text-sm text-muted">No resolvers configured and no Ruby repos yet.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Runtime</th>
              <th>Status</th>
              <th>Repos</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {resolvers.map((resolver) => {
              const [label, tone] = RESOLVER_STATUS[resolver.status]
              const enabled = resolver.repos.filter((repo) => repo.enabled).length
              return (
                <tr key={`${resolver.runtime}-${resolver.minor ?? "unknown"}`} className="align-top">
                  <td className="font-medium">
                    {RUNTIMES[resolver.runtime] ?? resolver.runtime} {resolver.minor ?? "?"}
                  </td>
                  <td>
                    <Badge tone={tone}>{label}</Badge>
                  </td>
                  <td>
                    {resolver.repos.length > 0 ? (
                      <details>
                        <summary className="cursor-pointer">
                          {enabled} enabled, {resolver.repos.length} total
                        </summary>
                        <ul className="mt-1 space-y-0.5">
                          {[...resolver.repos]
                            .sort((a, b) => Number(b.enabled) - Number(a.enabled))
                            .map((repo) => (
                              <li key={repo.id}>
                                <Link to={`/repos/${repo.fullName}`} className="hover:underline">
                                  <code>{repo.fullName}</code>
                                </Link>
                                {repo.enabled && (
                                  <span className="ml-1">
                                    <Badge tone="blue">enabled</Badge>
                                  </span>
                                )}
                              </li>
                            ))}
                        </ul>
                      </details>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="text-sm text-muted">{resolverHint(resolver)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}
    </div>
  )
}

const Credentials = () => {
  const [host, setHost] = useState("")
  const [secret, setSecret] = useState("")
  const [replacing, setReplacing] = useState<number | null>(null)
  const [replacement, setReplacement] = useState("")

  const queryClient = useQueryClient()
  const { data: credentials = [] } = useQuery({
    queryKey: ["gem_source_credentials"],
    queryFn: () => apiGemSourceCredentials.index<GemSourceCredential[]>(),
  })
  const refresh = () => queryClient.invalidateQueries({ queryKey: ["gem_source_credentials"] })

  const create = useMutation({
    mutationFn: () => apiGemSourceCredentials.create({ data: { host, secret } }),
    onSuccess: () => {
      setHost("")
      setSecret("")
      refresh()
    },
  })
  const replace = useMutation({
    mutationFn: (id: number) => apiGemSourceCredentials.update({ params: { id }, data: { secret: replacement } }),
    onSuccess: () => {
      setReplacing(null)
      setReplacement("")
      refresh()
    },
  })
  const remove = useMutation({
    mutationFn: (id: number) => apiGemSourceCredentials.destroy({ params: { id } }),
    onSuccess: refresh,
  })
  const error = errorMessage(create.error ?? replace.error ?? remove.error)

  const handleCreate = (event: React.FormEvent) => {
    event.preventDefault()
    create.mutate()
  }

  const handleReplace = (event: React.FormEvent, id: number) => {
    event.preventDefault()
    replace.mutate(id)
  }

  return (
    <div className="card space-y-3">
      <h2 className="subheading">Private gem sources</h2>
      <p className="text-sm text-muted">
        Credentials for private gem servers, e.g. <code>rubygems.pkg.github.com</code> (a PAT with read:packages) or{" "}
        <code>gems.contribsys.com</code> (<code>user:pass</code>). Stored encrypted and never shown again.
      </p>
      {error && <p className="text-sm text-flag-red">{error}</p>}

      {credentials.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Host</th>
              <th>Bundler env</th>
              <th>Updated</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {credentials.map((credential) => (
              <tr key={credential.id}>
                <td>{credential.host}</td>
                <td>
                  <code className="text-xs">{credential.envKey}</code>
                </td>
                <td className="text-muted">{timeAgo(credential.updatedAt)}</td>
                <td className="text-right">
                  {replacing === credential.id ? (
                    <form onSubmit={(e) => handleReplace(e, credential.id)} className="flex justify-end gap-2">
                      <input
                        type="password"
                        className="input"
                        placeholder="New secret"
                        value={replacement}
                        onChange={(e) => setReplacement(e.target.value)}
                        autoComplete="off"
                      />
                      <button type="submit" className="btn-primary" disabled={replace.isPending}>
                        Save
                      </button>
                      <button type="button" className="btn" onClick={() => setReplacing(null)}>
                        Cancel
                      </button>
                    </form>
                  ) : (
                    <span className="space-x-2">
                      <button type="button" className="btn" onClick={() => setReplacing(credential.id)}>
                        Replace secret
                      </button>
                      <button
                        type="button"
                        className="btn-danger"
                        onClick={() => remove.mutate(credential.id)}
                        disabled={remove.isPending}
                      >
                        Delete
                      </button>
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <form onSubmit={handleCreate} className="flex flex-wrap gap-2">
        <input className="input w-64" placeholder="Host" value={host} onChange={(e) => setHost(e.target.value)} />
        <input
          type="password"
          className="input w-64"
          placeholder="Secret"
          value={secret}
          onChange={(e) => setSecret(e.target.value)}
          autoComplete="off"
        />
        <button type="submit" className="btn-primary" disabled={create.isPending || !host || !secret}>
          Add
        </button>
      </form>
    </div>
  )
}

export default Settings
