import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"

import { errorMessage } from "../../lib/format"
import { apiSettings } from "../../lib/routes"
import type { Settings as ISettings } from "../../types"

const BranchNames = ({ settings }: { settings: ISettings | undefined }) => {
  const date = new Date().toISOString().slice(0, 10).replaceAll("-", "")
  const [separator, setSeparator] = useState(".")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()

  useEffect(() => {
    if (settings) setSeparator(settings.branchSeparator)
  }, [settings])

  const save = useMutation({
    mutationFn: () => apiSettings.update({ data: { setting: { branchSeparator: separator } } }),
    onSuccess: () => {
      setNotice("Saved. Open PRs keep their current branch.")
      queryClient.invalidateQueries({ queryKey: ["settings"] })
    },
  })

  const handleSave = (event: React.FormEvent) => {
    event.preventDefault()
    save.mutate()
  }

  return (
    <form onSubmit={handleSave} className="card space-y-3">
      <h2 className="subheading">Branch names</h2>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span>Separator</span>
        <select
          className="input font-mono"
          aria-label="Branch separator"
          value={separator}
          onChange={(e) => setSeparator(e.target.value)}
        >
          {settings?.branchSeparators.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
        <span className="text-muted">Preview:</span>
        <code>
          pitcrew{separator}security-{date}
        </code>
      </div>
      <p className="text-sm text-muted">A second PR for the same repo on the same day gets -2, -3 and so on.</p>
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {save.error && <p className="text-sm text-flag-red">{errorMessage(save.error)}</p>}
      <button type="submit" className="btn-primary" disabled={save.isPending}>
        Save
      </button>
    </form>
  )
}

export default BranchNames
