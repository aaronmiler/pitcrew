import { useState } from "react"

interface ISparkline {
  values: (number | null)[]
  // Tooltip text per point.
  labels: string[]
  width?: number
  height?: number
}

const PAD = 4

// A small trend line in the muted ink, the latest point in the accent. Nulls (nothing to
// measure that week) break the line. Hovering shows the nearest week; the weekly table
// below is the full view.
const Sparkline = ({ values, labels, width = 132, height = 32 }: ISparkline) => {
  const [hovered, setHovered] = useState<number | null>(null)

  const present = values.filter((value): value is number => value !== null)
  if (present.length === 0) return <div style={{ height }} />

  const max = Math.max(...present)
  const min = Math.min(0, ...present)
  const step = (width - PAD * 2) / Math.max(values.length - 1, 1)
  const x = (index: number) => PAD + index * step
  const y = (value: number) => height - PAD - ((value - min) / (max - min || 1)) * (height - PAD * 2)

  // One path segment per run of non-null values.
  const path = values
    .map((value, index) => {
      if (value === null) return ""
      const command = index === 0 || values[index - 1] === null ? "M" : "L"
      return `${command}${x(index).toFixed(1)},${y(value).toFixed(1)}`
    })
    .join(" ")

  const last = values.length - 1
  const lastValue = values[last]
  const hoveredValue = hovered === null ? null : values[hovered]

  const handleMove = (event: React.PointerEvent<SVGSVGElement>) => {
    const left = event.currentTarget.getBoundingClientRect().left
    const index = Math.round((event.clientX - left - PAD) / step)
    setHovered(Math.min(Math.max(index, 0), last))
  }

  return (
    <div className="relative" style={{ width }}>
      <svg
        width={width}
        height={height}
        className="block overflow-visible"
        role="img"
        aria-label={labels[last]}
        onPointerMove={handleMove}
        onPointerLeave={() => setHovered(null)}
      >
        {hovered !== null && (
          <line
            x1={x(hovered)}
            x2={x(hovered)}
            y1={0}
            y2={height}
            stroke="var(--color-hairline-strong)"
            strokeWidth={1}
          />
        )}
        <path
          d={path}
          fill="none"
          stroke="var(--color-muted)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {lastValue !== null && <circle cx={x(last)} cy={y(lastValue)} r={4} fill="var(--color-accent)" />}
        {hovered !== null && hoveredValue !== null && hovered !== last && (
          <circle
            cx={x(hovered)}
            cy={y(hoveredValue)}
            r={4}
            fill="var(--color-ink)"
            stroke="var(--color-surface)"
            strokeWidth={2}
          />
        )}
      </svg>
      {hovered !== null && (
        <div
          className="pointer-events-none absolute bottom-full z-10 mb-2 -translate-x-1/2 border border-hairline-strong bg-surface px-2 py-1 text-xs whitespace-nowrap text-ink shadow-sm"
          style={{ left: x(hovered) }}
        >
          {labels[hovered]}
        </div>
      )}
    </div>
  )
}

export default Sparkline
