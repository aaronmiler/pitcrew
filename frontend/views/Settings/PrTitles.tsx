import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"

import { errorMessage } from "../../lib/format"
import { apiSettings } from "../../lib/routes"
import type { Settings as ISettings } from "../../types"

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

const PrTitles = ({ settings }: { settings: ISettings | undefined }) => {
  const [template, setTemplate] = useState("")
  const [toolingTemplate, setToolingTemplate] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()

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
  )
}

export default PrTitles
