# Pitcrew

Keeps Ruby dependencies free of known CVEs so `bundle audit` never blocks a deploy.
Pitcrew polls [ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db), scans
selected GitHub repos, makes the smallest lockfile change that clears each advisory, and
opens one PR per repo. It replaces Dependabot for Ruby.

## How it works

1. **Advisories:** pulls ruby-advisory-db every 15 minutes (the same source `bundle audit` uses).
2. **Repos:** checks each enabled repo's `Gemfile.lock` through the GitHub API and scans it when it changes.
3. **Fix:** for each vulnerable gem, runs `bundle lock --update <gem> --conservative`
   (`--patch`, then `--minor`) in a resolver sidecar for the repo's Ruby version, and
   re-audits. Nothing is installed, and the Gemfile is never edited.
4. **PR:** opens one PR per repo with every fix, or updates the one already open. Anything
   that needs a major bump or a Gemfile change is listed for a human.
5. **Report:** tracks every finding, PR, and status change, and reports exposure windows
   and auto-fix rates.

See `PLAN.md` for the full design.

## Stack

| | |
|---|---|
| Backend | Ruby 3.4, Rails 8.1, Postgres, good_job, httpx, Blueprinter |
| Frontend | React 19, TypeScript, react-router 7, TanStack Query, Tailwind 4, Vite |
| Tests | RSpec, FactoryBot, shoulda-matchers, WebMock |
| Quality | RuboCop (omakase + evergreen), Prettier, Brakeman, bundler-audit |
| Resolver | Go (stdlib only), static binary layered onto each Ruby image |
| Deploy | Docker + Thruster |

## Getting started

Start Postgres (any local instance on `localhost:5432` works):

```sh
docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:16
```

Then set up and run:

```sh
bin/setup   # installs gems + yarn packages, syncs style config, prepares the DB, starts the server
bin/dev     # later runs: Rails + Vite dev server
```

Visit `http://localhost:3000`. The GitHub App env vars (see Deployment → GitHub App) are
needed for sign-in and repo access. For fixes, start the resolver sidecars:
`docker compose -f docker-compose.resolvers.yml up -d --build`, with
`RESOLVER_RUBY_3_3=http://127.0.0.1:9333` and `RESOLVER_RUBY_3_4=http://127.0.0.1:9334` in `.env`.

Other endpoints: `GET /up` (health check) and `/good_job` (job dashboard, development only).

## Checks

```sh
bin/ci
```

Runs RuboCop, Prettier, TypeScript, RSpec, the resolver's Go checks (`gofmt`, `go vet`,
`go test`), Brakeman, and bundler-audit. GitHub Actions
runs the same checks on every push and PR.

## Conventions

- **Services:** POROs in `app/services/` inherit from `ApplicationService`. Arguments go
  to `.call`, never to `#initialize`.
- **API:** controllers in `app/controllers/api/`, serializers in `app/blueprints/`. Mark a
  route `defaults: { export: true }` to generate its TypeScript helper.
- **SPA routing:** there's no catch-all route by default. Add one when client-side routes
  arrive (there's an example in `config/routes.rb`).
- **Frameworks:** Active Storage, Action Mailer, Action Mailbox, Action Text, and Action
  Cable are off in `config/application.rb` (no uploads, no email, no push). Jobs and cron
  run on good_job; there's no Solid Queue/Cache/Cable and no Redis.

## Deployment

Pitcrew is three kinds of container: the app (web), a job runner, and one resolver
sidecar per Ruby minor. CI publishes the images on every green push to `main`:

| Image | What it is |
|---|---|
| `ghcr.io/aaronmiler/pitcrew:latest` (and `:<sha>`) | The app. Runs the web server by default; `bundle exec good_job start` runs the job runner from the same image |
| `ghcr.io/aaronmiler/pitcrew-resolver:ruby-3.2`, `:ruby-3.3`, `:ruby-3.4`, `:ruby-4.0` (and `:ruby-X.Y-<sha>`) | A resolver sidecar: the Go server in `resolver/` on top of `ruby:X.Y-slim`. It runs `bundle lock` for repos on that Ruby |

Need another Ruby? Build it from the same Dockerfile:

```sh
docker build -f Dockerfile.resolver --build-arg BASE=ruby:3.1-slim -t pitcrew-resolver:ruby-3.1 .
```

Very old Rubies (2.x) work with friction: their images are on archived Debian releases (the
`apt-get` step may need `archive.debian.org`) and ship an old Bundler.

### Example compose

An example to adapt, not a file Pitcrew needs: your host's own compose file runs it.

```yaml
services:
  pitcrew:
    image: ghcr.io/aaronmiler/pitcrew:latest
    env_file: .env
    environment: &resolvers
      PITCREW_WORK_DIR: /work
      RESOLVER_RUBY_3_3: http://pitcrew-ruby33:9292
      RESOLVER_RUBY_3_4: http://pitcrew-ruby34:9292
    ports:
      - "3000:80"
    volumes:
      - storage:/rails/storage   # ruby-advisory-db checkout
      - work:/work               # checkouts handed to the resolvers
    networks: [default, resolvers]
    depends_on: [db]
    restart: unless-stopped

  pitcrew-jobs:
    image: ghcr.io/aaronmiler/pitcrew:latest
    command: bundle exec good_job start
    env_file: .env
    environment: *resolvers
    volumes:
      - storage:/rails/storage
      - work:/work
    networks: [default, resolvers]
    depends_on: [db]
    restart: unless-stopped

  # No published ports: only Pitcrew can reach them, on the resolvers network.
  pitcrew-ruby34:
    image: ghcr.io/aaronmiler/pitcrew-resolver:ruby-3.4
    volumes:
      - work:/work
    networks: [resolvers]
    restart: unless-stopped

  pitcrew-ruby33:
    image: ghcr.io/aaronmiler/pitcrew-resolver:ruby-3.3
    volumes:
      - work:/work
    networks: [resolvers]
    restart: unless-stopped

  # Drop this and set DATABASE_URL if you have a Postgres already.
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - db:/var/lib/postgresql/data
    restart: unless-stopped

networks:
  resolvers:
    internal: true

volumes:
  storage:
  work:
  db:
```

Notes:

- **One container instead of two:** drop `pitcrew-jobs` and set `GOOD_JOB_EXECUTION_MODE=async`
  on `pitcrew`, so jobs and cron run inside the web process. Fine for a handful of repos.
- **`/work` must be the same volume at the same path** in whatever runs jobs and in every
  resolver: the app clones a repo there and the resolver runs Bundler in that clone. The
  web container mounts it too, so you can switch to async mode without changing volumes.
- **Both app containers need the resolvers network:** jobs to resolve, web for the
  Settings → Resolvers status check.
- **Postgres is required.** GoodJob and the schema (arrays, jsonb) are Postgres-only.
- **Migrations** run when the web container boots (`db:prepare`).

### Environment

| Variable | |
|---|---|
| `SECRET_KEY_BASE` | Generate with `bin/rails secret` |
| `DATABASE_URL` | `postgres://user:password@host:5432/pitcrew_production` (with the example's `db` service: `postgres://postgres:postgres@db:5432/pitcrew_production`) |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | Encrypts gem source credentials. Generate the three keys with `bin/rails db:encryption:init` |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | |
| `GITHUB_APP_ID` | From the GitHub App's settings (see below) |
| `GITHUB_APP_PRIVATE_KEY` | The App's PEM private key, **on one line** with literal `\n` between lines (Docker env files and foreman's `.env` loader truncate multi-line values). Convert with `awk '{printf "%s\\n", $0}' key.pem` |
| `GITHUB_APP_CLIENT_ID` | The App's client id, for sign-in |
| `GITHUB_APP_CLIENT_SECRET` | The App's client secret, for sign-in |
| `PITCREW_INITIAL_USER` | GitHub login allowed to sign in while there are no users yet. Ignored once anyone exists; after that, manage access (invites, allowed orgs) in the UI |
| `RESOLVER_<RUNTIME>_<MAJOR>_<MINOR>` | One per resolver sidecar, by compose service name: `RESOLVER_RUBY_3_4=http://pitcrew-ruby34:9292` (env names can't hold dots, hence `3_4`). A repo on a Ruby with no resolver gets a `needs_attention` finding; Settings → Resolvers shows what's missing |
| `PITCREW_WORK_DIR` | `/work`, the shared volume above (default `tmp/work`, for development). Set in the example compose |
| `GOOD_JOB_EXECUTION_MODE` | Optional. `async` runs jobs inside the web process (see Notes). Default: a separate `good_job start` container |
| `RAILS_MAX_THREADS` | Optional, default 5. Sets Puma threads and the DB pool. In async mode, set it to 10 so jobs get connections too |
| `ADVISORY_DB_PATH` | Optional. Where the ruby-advisory-db checkout lives (default `storage/ruby-advisory-db`, on the `storage` volume above) |

### GitHub App

Pitcrew acts as a GitHub App: it reads repos and opens PRs as `<app-name>[bot]`, and signs
people in with the App's OAuth credentials. Create one per Pitcrew instance (a separate
App for local development keeps dev from touching your real repos), under your account or
org: **Settings → Developer settings → GitHub Apps → New GitHub App**.

- **Callback URL:** `https://<your-pitcrew-host>/auth/github/callback` (add
  `http://localhost:3000/auth/github/callback` on a dev App)
- **Webhook:** uncheck **Active**. Pitcrew polls; it needs no inbound access.
- **Repository permissions:**

  | Permission | Access | Used for |
  |---|---|---|
  | Contents | Read and write | Reading lockfiles, cloning, writing the lockfile commit to `pitcrew/*` branches, merging the default branch into its PR branch, deleting its branch after merge |
  | Pull requests | Read and write | Opening, updating, commenting on and closing its PR |
  | Checks | Read | CI status on the PR (check runs) |
  | Commit statuses | Read | CI status on the PR (legacy statuses) |
  | Metadata | Read | Required by GitHub |

- **Organization permissions:** Members, Read (only for the "allowed orgs" sign-in option).
- **Account permissions:** none.
- **Where can this GitHub App be installed?** Only on this account.

After creating it: note the **App ID** and **Client ID**, generate a **client secret** and
a **private key**, then **Install App** on the repos Pitcrew should see (all, or a
selection). Sync them from the Repos page and enable the ones to fix.

## Using your own style config

`.rubocop.yml` and `bin/sync-style` point at [evergreen](https://github.com/aaronmiler/evergreen).
To use your own rules, point those two URLs at your fork, or replace them with local config files.

## License

[MIT](LICENSE)
