import { useState } from "react"

// Spread into a useQuery for data that background jobs change (scans, PRs, failures).
// Polling keeps the current data on screen and skips re-rendering when nothing changed,
// so the page only moves when there's something new. Hidden tabs don't poll.
export const LIVE = { refetchInterval: 15_000, refetchOnWindowFocus: true } as const

// A Refresh button's busy state, for clicks only. A query's isFetching is also true
// during background polls, which would flash the button every interval.
export const useManualRefresh = (refetch: () => Promise<unknown>) => {
  const [refreshing, setRefreshing] = useState(false)

  const refresh = async () => {
    setRefreshing(true)
    try {
      await refetch()
    } finally {
      setRefreshing(false)
    }
  }

  return { refresh, refreshing }
}
