const UNITS: [Intl.RelativeTimeFormatUnit, number][] = [
  ["year", 365 * 24 * 3600],
  ["month", 30 * 24 * 3600],
  ["day", 24 * 3600],
  ["hour", 3600],
  ["minute", 60],
]

const relative = new Intl.RelativeTimeFormat("en", { numeric: "auto" })

// "3 hours ago", "yesterday", "just now"
export const timeAgo = (iso: string | null | undefined): string => {
  if (!iso) return "never"
  const seconds = (new Date(iso).getTime() - Date.now()) / 1000
  for (const [unit, size] of UNITS) {
    if (Math.abs(seconds) >= size) return relative.format(Math.round(seconds / size), unit)
  }
  return "just now"
}

export const pluralize = (count: number, word: string, plural = `${word}s`) => `${count} ${count === 1 ? word : plural}`

// Validation messages from a failed API call ({ errors: [...] } or { error: "..." }).
export const errorMessage = (error: unknown): string | null => {
  if (!error) return null
  const body = (error as { body?: { errors?: string[]; error?: string } }).body
  return body?.errors?.join(" ") ?? body?.error ?? "Something went wrong."
}
