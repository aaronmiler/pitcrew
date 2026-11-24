import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { createBrowserRouter, RouterProvider } from "react-router"

import Layout from "../components/Layout"
import Access from "../views/Access/Access"
import Advisories from "../views/Advisories/Advisories"
import Reports from "../views/Reports/Reports"
import Repo from "../views/Repo/Repo"
import Repos from "../views/Repos/Repos"
import Settings from "../views/Settings/Settings"
import "./application.css"

// No polling by default. Queries for data that jobs change opt in with LIVE (lib/refresh.ts);
// settings and forms don't, so a poll never overwrites an edit in progress.
const queryClient = new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
})

const router = createBrowserRouter([
  {
    path: "/",
    element: <Layout />,
    children: [
      { index: true, element: <Repos /> },
      { path: "repos/:owner/:name", element: <Repo /> },
      { path: "repos/:id", element: <Repo /> }, // old links; redirects to the owner/name URL
      { path: "advisories", element: <Advisories /> },
      { path: "reports", element: <Reports /> },
      { path: "access", element: <Access /> },
      { path: "settings", element: <Settings /> },
    ],
  },
])

const container = document.getElementById("root")

if (container) {
  createRoot(container).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </StrictMode>
  )
}
