import Sparkline from "../../components/Sparkline"

interface IDelta {
  current: number | null
  previous: number | null | undefined
  upIsGood: boolean
  format: (value: number) => string
  period: string
}

// Change vs the previous period: an arrow and the amount, green when it moved the good way.
export const Delta = ({ current, previous, upIsGood, format, period }: IDelta) => {
  if (current === null || previous === null || previous === undefined) return null
  const diff = current - previous
  const vs = <span className="font-normal text-muted">vs previous {period}</span>
  if (diff === 0) return <span className="text-xs text-muted">no change {vs}</span>
  const good = diff > 0 === upIsGood
  return (
    <span className={`text-xs font-semibold ${good ? "text-flag-green" : "text-flag-red"}`}>
      {diff > 0 ? "▲" : "▼"} {format(Math.abs(diff))} {vs}
    </span>
  )
}

interface ITile {
  label: string
  value: string
  delta?: React.ReactNode
  values: (number | null)[]
  labels: string[]
}

const Tile = ({ label, value, delta, values, labels }: ITile) => (
  <div className="card flex flex-col gap-2">
    <span className="label">{label}</span>
    <span className="font-display text-[32px] leading-none font-semibold text-ink">{value}</span>
    <span className="min-h-4">{delta}</span>
    <Sparkline values={values} labels={labels} />
    <span className="text-[11px] text-muted">Last 12 weeks</span>
  </div>
)

export default Tile
