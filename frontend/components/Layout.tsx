import { useQuery } from "@tanstack/react-query"
import { NavLink, Outlet, useLocation } from "react-router"

import { apiSessions } from "../lib/routes"
import type { User } from "../types"
import ServiceStatus from "./ServiceStatus"

// `also`: a path prefix that marks the link current too (a repo's page lives under /repos/).
const LINKS = [
  { to: "/", label: "Repos", end: true, also: "/repos/" },
  { to: "/advisories", label: "Advisories", end: false },
  { to: "/access", label: "Access", end: false },
  { to: "/settings", label: "Settings", end: false },
]

const csrfToken = () => document.querySelector<HTMLMetaElement>("meta[name=csrf-token]")?.content ?? ""

const Layout = () => {
  const { data: user } = useQuery({ queryKey: ["session"], queryFn: () => apiSessions.show<User>() })
  const { pathname } = useLocation()

  return (
    <div className="min-h-screen">
      <header className="livery">
        <nav className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
          <span className="livery-brand">Pitcrew</span>
          {LINKS.map(({ to, label, end, also }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                isActive || (also && pathname.startsWith(also)) ? "livery-link active" : "livery-link"
              }
            >
              {label}
            </NavLink>
          ))}
          {user && (
            <form
              method="post"
              action="/sign_out"
              className="ml-auto flex items-center gap-3 text-xs text-on-chrome-soft"
            >
              <span className="font-mono">@{user.githubLogin}</span>
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name="authenticity_token" value={csrfToken()} />
              <button type="submit" className="livery-link">
                Sign out
              </button>
            </form>
          )}
        </nav>
      </header>
      <ServiceStatus />
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}

export default Layout
