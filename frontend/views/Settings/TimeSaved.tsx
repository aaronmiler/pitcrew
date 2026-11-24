import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"

import { errorMessage } from "../../lib/format"
import { apiSettings } from "../../lib/routes"
import type { Settings as ISettings } from "../../types"

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

export default TimeSaved
