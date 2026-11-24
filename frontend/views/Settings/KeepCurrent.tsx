import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"

import { errorMessage } from "../../lib/format"
import { apiSettings } from "../../lib/routes"
import type { Settings as ISettings } from "../../types"

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

export default KeepCurrent
