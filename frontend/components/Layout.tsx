import { useQuery } from "@tanstack/react-query"
import { NavLink, Outlet } from "react-router"

import { apiSessions } from "../lib/routes"
import type { User } from "../types"

const LINKS = [
  { to: "/", label: "Repos", end: true },
  { to: "/advisories", label: "Advisories", end: false },
  { to: "/access", label: "Access", end: false },
  { to: "/settings", label: "Settings", end: false },
]

const csrfToken = () => document.querySelector<HTMLMetaElement>("meta[name=csrf-token]")?.content ?? ""

const Layout = () => {
  const { data: user } = useQuery({ queryKey: ["session"], queryFn: () => apiSessions.show<User>() })

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <header className="border-b border-gray-200 bg-white">
        <nav className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3 text-sm">
          <span className="font-semibold">Pitcrew</span>
          {LINKS.map(({ to, label, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                isActive ? "font-medium text-gray-900" : "text-gray-500 hover:text-gray-900"
              }
            >
              {label}
            </NavLink>
          ))}
          {user && (
            <form method="post" action="/sign_out" className="ml-auto flex items-center gap-2 text-gray-500">
              <span>@{user.githubLogin}</span>
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name="authenticity_token" value={csrfToken()} />
              <button type="submit" className="underline hover:text-gray-900">
                Sign out
              </button>
            </form>
          )}
        </nav>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}

export default Layout
