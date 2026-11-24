import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useEffect, useState } from "react"

import Badge from "../../components/Badge"
import { errorMessage } from "../../lib/format"
import { apiSessions, apiSettings, apiUsers } from "../../lib/routes"
import type { Settings, User } from "../../types"

const Access = () => {
  const [login, setLogin] = useState("")
  const [orgs, setOrgs] = useState("")
  const [notice, setNotice] = useState<string | null>(null)

  const queryClient = useQueryClient()
  const { data: me } = useQuery({ queryKey: ["session"], queryFn: () => apiSessions.show<User>() })
  const { data: users = [] } = useQuery({ queryKey: ["users"], queryFn: () => apiUsers.index<User[]>() })
  const { data: settings } = useQuery({ queryKey: ["settings"], queryFn: () => apiSettings.show<Settings>() })

  useEffect(() => {
    if (settings) setOrgs(settings.allowedOrgs.join(", "))
  }, [settings])

  const invite = useMutation({
    mutationFn: () => apiUsers.create({ data: { githubLogin: login } }),
    onSuccess: () => {
      setNotice(`Invited @${login}. They can sign in with GitHub now.`)
      setLogin("")
      queryClient.invalidateQueries({ queryKey: ["users"] })
    },
  })
  const remove = useMutation({
    mutationFn: (user: User) => apiUsers.destroy({ params: { id: user.id } }),
    onSuccess: (_, user) => {
      setNotice(`Removed @${user.githubLogin}.`)
      queryClient.invalidateQueries({ queryKey: ["users"] })
    },
  })
  const saveOrgs = useMutation({
    mutationFn: () =>
      apiSettings.update({ data: { setting: { allowedOrgs: orgs.split(",").map((org) => org.trim()) } } }),
    onSuccess: () => {
      setNotice("Allowed orgs saved.")
      queryClient.invalidateQueries({ queryKey: ["settings"] })
    },
  })
  const error = errorMessage(invite.error ?? remove.error ?? saveOrgs.error)

  const handleInvite = (event: React.FormEvent) => {
    event.preventDefault()
    if (login.trim()) invite.mutate()
  }

  const handleSaveOrgs = (event: React.FormEvent) => {
    event.preventDefault()
    saveOrgs.mutate()
  }

  return (
    <section className="space-y-6">
      <h1 className="heading">Access</h1>
      {notice && <p className="text-sm text-muted">{notice}</p>}
      {error && <p className="text-sm text-flag-red">{error}</p>}

      <div className="space-y-2">
        <h2 className="subheading">People</h2>
        <table className="table">
          <thead>
            <tr>
              <th>GitHub login</th>
              <th>Access</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.id}>
                <td>
                  <code>@{user.githubLogin}</code>
                  {user.name && <span className="ml-1 text-muted">{user.name}</span>}
                </td>
                <td className="space-x-1">
                  <Badge tone={user.accessVia === "org" ? "blue" : "gray"}>
                    {user.accessVia === "org" ? "via org" : "invited"}
                  </Badge>
                  {user.pending && <Badge tone="amber">hasn't signed in yet</Badge>}
                </td>
                <td className="text-right">
                  {user.id !== me?.id && (
                    <button
                      type="button"
                      className="btn-danger"
                      onClick={() => remove.mutate(user)}
                      disabled={remove.isPending}
                    >
                      Remove
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <form onSubmit={handleInvite} className="flex gap-2">
          <input
            className="input w-64"
            placeholder="GitHub login"
            value={login}
            onChange={(e) => setLogin(e.target.value)}
          />
          <button type="submit" className="btn-primary" disabled={invite.isPending}>
            Invite
          </button>
        </form>
      </div>

      <form onSubmit={handleSaveOrgs} className="card space-y-2">
        <h2 className="subheading">Allowed orgs</h2>
        <p className="text-sm text-muted">
          Members of these GitHub orgs can sign in. Membership is checked at every sign-in, and the GitHub App needs the
          org&rsquo;s &ldquo;Members: read&rdquo; permission.
        </p>
        <div className="flex gap-2">
          <input
            className="input w-96"
            placeholder="acme, widgets"
            value={orgs}
            onChange={(e) => setOrgs(e.target.value)}
          />
          <button type="submit" className="btn-primary" disabled={saveOrgs.isPending}>
            Save
          </button>
        </div>
      </form>
    </section>
  )
}

export default Access
