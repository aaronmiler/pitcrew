import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useState } from "react"

import { errorMessage, timeAgo } from "../../lib/format"
import { apiGemSourceCredentials } from "../../lib/routes"
import type { GemSourceCredential } from "../../types"

const Credentials = () => {
  const [host, setHost] = useState("")
  const [secret, setSecret] = useState("")
  const [replacing, setReplacing] = useState<number | null>(null)
  const [replacement, setReplacement] = useState("")

  const queryClient = useQueryClient()
  const { data: credentials = [] } = useQuery({
    queryKey: ["gem_source_credentials"],
    queryFn: () => apiGemSourceCredentials.index<GemSourceCredential[]>(),
  })
  const refresh = () => queryClient.invalidateQueries({ queryKey: ["gem_source_credentials"] })

  const create = useMutation({
    mutationFn: () => apiGemSourceCredentials.create({ data: { host, secret } }),
    onSuccess: () => {
      setHost("")
      setSecret("")
      refresh()
    },
  })
  const replace = useMutation({
    mutationFn: (id: number) => apiGemSourceCredentials.update({ params: { id }, data: { secret: replacement } }),
    onSuccess: () => {
      setReplacing(null)
      setReplacement("")
      refresh()
    },
  })
  const remove = useMutation({
    mutationFn: (id: number) => apiGemSourceCredentials.destroy({ params: { id } }),
    onSuccess: refresh,
  })
  const error = errorMessage(create.error ?? replace.error ?? remove.error)

  const handleCreate = (event: React.FormEvent) => {
    event.preventDefault()
    create.mutate()
  }

  const handleReplace = (event: React.FormEvent, id: number) => {
    event.preventDefault()
    replace.mutate(id)
  }

  return (
    <div className="card space-y-3">
      <h2 className="subheading">Private gem sources</h2>
      <p className="text-sm text-muted">
        Credentials for private gem servers, e.g. <code>rubygems.pkg.github.com</code> (a PAT with read:packages) or{" "}
        <code>gems.contribsys.com</code> (<code>user:pass</code>). Stored encrypted and never shown again.
      </p>
      {error && <p className="text-sm text-flag-red">{error}</p>}

      {credentials.length > 0 && (
        <table className="table">
          <thead>
            <tr>
              <th>Host</th>
              <th>Bundler env</th>
              <th>Updated</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {credentials.map((credential) => (
              <tr key={credential.id}>
                <td>{credential.host}</td>
                <td>
                  <code className="text-xs">{credential.envKey}</code>
                </td>
                <td className="text-muted">{timeAgo(credential.updatedAt)}</td>
                <td className="text-right">
                  {replacing === credential.id ? (
                    <form onSubmit={(e) => handleReplace(e, credential.id)} className="flex justify-end gap-2">
                      <input
                        type="password"
                        className="input"
                        placeholder="New secret"
                        value={replacement}
                        onChange={(e) => setReplacement(e.target.value)}
                        autoComplete="off"
                      />
                      <button type="submit" className="btn-primary" disabled={replace.isPending}>
                        Save
                      </button>
                      <button type="button" className="btn" onClick={() => setReplacing(null)}>
                        Cancel
                      </button>
                    </form>
                  ) : (
                    <span className="space-x-2">
                      <button type="button" className="btn" onClick={() => setReplacing(credential.id)}>
                        Replace secret
                      </button>
                      <button
                        type="button"
                        className="btn-danger"
                        onClick={() => remove.mutate(credential.id)}
                        disabled={remove.isPending}
                      >
                        Delete
                      </button>
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <form onSubmit={handleCreate} className="flex flex-wrap gap-2">
        <input className="input w-64" placeholder="Host" value={host} onChange={(e) => setHost(e.target.value)} />
        <input
          type="password"
          className="input w-64"
          placeholder="Secret"
          value={secret}
          onChange={(e) => setSecret(e.target.value)}
          autoComplete="off"
        />
        <button type="submit" className="btn-primary" disabled={create.isPending || !host || !secret}>
          Add
        </button>
      </form>
    </div>
  )
}

export default Credentials
