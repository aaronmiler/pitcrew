# Pitcrew — Plan

Replaces Dependabot for Ruby CVEs. Polls ruby-advisory-db (the same source bundler-audit
uses to block deploys), scans selected GitHub repos, makes the smallest lockfile change
that clears the advisories, and opens/maintains one PR per repo. Tracks everything and
reports its value.

Lineage: the fix loop is a port of `rails-toolkit/scripts/gem_audit.rb` (weekly Action).
Pitcrew runs it centrally and frequently, resolves without installing, and its PRs
trigger CI (App token, not `GITHUB_TOKEN`).

## Stack

- Base: `sapling` (Rails 8.1, Ruby 3.4.9, RSpec + FactoryBot, Vite)
- Postgres + **GoodJob** (cron built in; no Redis)
- Octokit + GitHub App (bot for repos/PRs, and OAuth for login)
- Services inherit `ApplicationService`; rails commands via `docker compose exec`
- Styling: Tailwind v4 "livery" theme (2026-11-23), all tokens in `frontend/entrypoints/application.css`; light/dark follow the system. Square corners, thin border lines, uppercase letter-spaced labels. Accent blue `#2a62d4`; header livery is a slanted deep-blue panel behind the wordmark with a pale pin and San Remo-green trim (our own colors, not a team's). Status colors follow racing flags (red open, yellow needs attention, green resolved, blue in PR). Fonts committed in `frontend/fonts/` (no outside requests): Inter body, Saira Condensed uppercase for page and section headings only (`.heading`/`.subheading`), JetBrains Mono for exact names (repos, gems, versions, advisory IDs) via `<code>`
- Deploy: tars Docker stack (app, good_job worker, postgres; volumes for advisory DB + Rubies)

## Decisions

| Topic | Decision |
|---|---|
| PR grouping | One PR per repo. A scan with N vulns → one PR with N fixes. Later findings update the open PR (merge default branch in, re-resolve; never force-push). Each PR gets its own branch `pitcrew/security-YYYYMMDD-HHMM`; after merge/close Pitcrew deletes its branch if GitHub did not |
| Update strategy | One call for everything: targets = all vulnerable gems + every gem connected to them by exact `(= x)` lockfile pins (lockstep families like Rails; computed, not hardcoded). `bundle lock --update <targets> --conservative --patch`; re-audit; recompute targets from what's still flagged and retry with `--minor`; anything left → `needs_attention` (reason from the lockfile's DEPENDENCIES constraints, e.g. a Gemfile pin, or "needs a major bump"). Never trust `bundle lock`'s exit code (it exits 0 on a no-op); the re-audit decides. Spike 2026-11-21 on a copy of esther: 65 advisories / 17 gems → 2 after `--patch` → 1 after `--minor` (rack-proxy needs a major); 25 gems changed, all targets; 0 installs. Per-gem calls fail here: Rails 8.1.4.1 needs rails-html-sanitizer ≥ 1.7.2, so resolving Rails alone silently settled on 8.1.4 |
| Git-sourced gems | Resolver needs read access to `git:`/`github:` gem sources. Public ones just work; for private GitHub ones, pass `BUNDLE_GITHUB__COM=x-access-token:<installation token>` (App installed on that repo) |
| Ruby versions | Resolve under the repo's Ruby **minor** line, in a resolver sidecar (below). Safety net: after resolving, check each changed gem's `required_ruby_version` against the repo's exact `.ruby-version`; on a violation → `needs_attention` |
| Resolver sidecars | One long-running container per Ruby minor (`ruby:X.Y-slim`, prebuilt). Isolates the repo's Gemfile (it's executable Ruby) from the app's DB creds/App key. No Docker socket. ~20–30 MB RAM idle each |
| Gemfile edits | Never. Pins that block a fix are reported, not changed |
| Auth (UI) | GitHub only, everywhere (most repeatable; the App is required anyway). GitHub App OAuth (`omniauth-github`) in one `Authentication` concern. Access: bootstrap with `PITCREW_INITIAL_USER=<login>`, honored only while `User.count.zero?` (unset → nobody can sign in; fails closed). After that, access is managed in the UI: invite by login (a pending `User`, uid filled on first sign-in, then matched by uid) and/or `Setting.allowed_orgs` (membership checked at every sign-in; needs the App's org "Members: read"). No roles: every user can do everything. PitPass/Paddock considered and rejected: not OmniAuth/OIDC, private gem source |
| Private gem sources | `GemSourceCredential` (host, encrypted secret via AR Encryption) → `BUNDLE_<HOST>` env at resolve time; never written to the clone |
| PR status | Polled (tars isn't internet-reachable, so no webhooks) |
| Advisories | Indexed in DB; the git checkout stays source of truth for scanning |
| LLM upgrade advice | Back pocket. Natural hook: `needs_attention` findings |
| Dependabot | Disabled in favor of Pitcrew. Comparison is vs GitHub Advisory DB publish time, not Dependabot PRs |
| rails-toolkit gem-audit | TBD (retire vs. keep as fallback) |
| JS/npm CVEs | Phased. Nothing blocks deploys on them, so the goal is triage (shipped vs build-only), not a green audit. `ecosystem` column from day one |

## Data model

- **Repository**: `full_name`, `default_branch`, `installation_id`, `enabled`, `lockfile_sha`, `runtimes` (jsonb runtime → version from the default branch, e.g. `{"ruby" => "3.4.9"}`; written by repo sync and each scan), `ecosystems` (string array from root lockfiles: bundler / npm / yarn / pnpm; nil until a sync checked), `last_scanned_at`, `locked_versions` (jsonb name → version, written by each scan)
- **Advisory**: `ecosystem` (rubygems / npm), `gem` (package name), `rubysec_id` (file id), `cve`, `ghsa` (unique where present), `title`, `url`, `criticality`, `patched_versions`, `unaffected_versions`, `published_on` (rubysec `date`), `rubysec_committed_at` (git log of the file), `ghsa_published_at`, `ghsa_reviewed_at`, `first_seen_at`
- **Finding**: `ecosystem`, repository, advisory, `locked_version`, `status` (open / in_pr / needs_attention / resolved), `reason`, `detected_at`, `resolved_at`. Unique `(repository_id, advisory_id)`
- **FixPullRequest**: repository, `number`, `branch`, `state` (open/merged/closed), `ci_status` (pending/passing/failing), `head_sha`, `opened_at`, `merged_at`, `closed_at`; has many findings. Partial unique index on `repository_id WHERE state = 'open'` (at most one open PR per repo, race-safe)
- **FindingEvent**: append-only: finding, `kind` (detected, pr_opened, pr_updated, needs_attention, merged, resolved), `occurred_at`, `metadata`
- **GemSourceCredential**: `host`, `secret` (encrypted)
- **GemRelease**: `name` (unique), `version`, `checked_at`: latest stable release of each kept-current gem
- **GemBump**: repository, fix_pull_request, `gem_name`, `from_version`, `to_version` (unique per PR + gem): what a PR's lockfile moves a kept-current gem by, relative to the default branch
- **User**: `github_uid` (nil while invited/pending; unique when set), `github_login` (unique, case-insensitive), `name`, `email`
- **Setting**: single row (`Setting.current`; unique `singleton` column), one typed column per setting. Edited in the UI. First: `pr_title_template` (default `chore(security): patch %{advisories} in %{gems}`; fields `count advisories gems gem_count ids repo date`; only `%{field}` is special, other `%` literal; unknown fields rejected on save); `allowed_orgs` (string array, normalized lowercase); `tooling_pr_title_template` (default `chore(deps): update %{gems}`, same fields; used when a PR fixes no advisory); `keep_current_gems` (string array, empty by default)

**Config split:** anything editable lives in the DB and the UI (settings, gem source credentials such as GitHub Packages `rubygems.pkg.github.com` and Sidekiq `gems.contribsys.com`). Env holds only bootstrap: `SECRET_KEY_BASE`, `DATABASE_URL`, the AR encryption keys (they encrypt the DB secrets), the GitHub App credentials (sign-in depends on them), and `PITCREW_INITIAL_USER` (one-time bootstrap).

## Jobs (GoodJob cron)

1. **AdvisoryDbSyncJob** (15m): `git pull` the advisory DB. On a HEAD change, import the changed files (`git diff old..new`), set `first_seen_at`/`rubysec_committed_at`, enqueue GhsaEnrichJob for those advisories, and enqueue ScanRepositoryJob for all enabled repos
2. **GhsaEnrichJob**: `GET /advisories/{ghsa}` → `ghsa_published_at`, `ghsa_reviewed_at`
3. **RepoSyncJob** (15m): one API call per repo to compare the default-branch `Gemfile.lock` blob SHA; on a change, enqueue a scan
4. **ScanRepositoryJob**: fetch the lockfile via API (no clone); `Bundler::Audit::Scanner` in a tmpdir; upsert findings and emit events; mark findings that disappeared as resolved. If new or open findings aren't covered by the open PR → FixRepositoryJob
5. **FixRepositoryJob**: shallow clone. Re-fetch the open PR's state from GitHub first (the DB copy can be up to 5m stale). Open PR → check out its branch, merge default in, take default's `Gemfile.lock` on conflict; no open PR → new `pitcrew/security-YYYYMMDD-HHMM` branch from default. Per vulnerable gem, run the ported gem_audit loop via the resolver sidecar for the repo's Ruby minor. Commit, push, open or update the PR (gem_audit's body table: patched + needs-attention). Close the PR if the default branch already fixed everything
6. **PullRequestSyncJob** (5m): poll open PRs for state and checks; on merge, mark findings resolved and emit events
7. **GemReleasesJob** (hourly, and on saving `keep_current_gems`): rubygems.org latest stable release per kept-current gem; on a new one, FixRepositoryJob (forced) for enabled repos now behind

## Resolver sidecars

- **Contract** (the seam): app shallow-clones into shared `/work/<job>`, POSTs `{dir, packages, level, env}` to `/resolve/<ecosystem>` (`/resolve/bundler`) on the resolver for the repo's Ruby minor; resolver runs `bundle lock --update <gem> --conservative --<level>` in that dir and returns exit status + output; the updated `Gemfile.lock` is left in place. All logic (patch→minor loop, re-audit, git, PRs) stays in the app
- **Resolver**: a Go server (stdlib only, `resolver/`), compiled to a static binary and layered onto each runtime's own image (`Dockerfile.resolver`, `BASE=ruby:3.4-slim`), so it doesn't depend on the image's Ruby. Was ~130 lines of Ruby until 2026-11-22; moved so old Ruby images and future Node images run the same server. Each ecosystem is one entry in `resolver/ecosystems.go` (tool, manifest, allowed names, allowed credential env keys, levels, command); a route is served only when its tool is in the image. `GET /health` reports `runtimes` and `ecosystems`. CI publishes `ghcr.io/aaronmiler/pitcrew-resolver:ruby-3.2` / `:ruby-3.3` / `:ruby-3.4` / `:ruby-4.0`; other Rubies build from the same Dockerfile
- **Routing**: `.ruby-version` minor → resolver host, read from the checkout being fixed (an open PR's branch can be on a newer Ruby than the default branch); falls back to `runtimes["ruby"]`. No resolver for that minor → `needs_attention` ("no resolver for Ruby 3.2"), never a silent fallback
- **Status**: Settings → Resolvers (`Resolver::Status`, `GET /api/resolvers`) lists each needed or configured `[runtime, minor]`: reachable / unreachable / wrong Ruby (its `/health` reports another minor) / not configured / unknown (Ruby repos without `.ruby-version`), with the repos it serves. Read-only; sidecars stay in env, one `RESOLVER_<RUNTIME>_<MAJOR>_<MINOR>=<url>` per sidecar (e.g. `RESOLVER_RUBY_3_4`)
- **Secrets**: gem source creds sent per request in `env`; never stored in the sidecar
- **Client**: one `Resolver::Client` class behind the contract, so other backends (e.g. ECS `RunTask` for work) can be added later without touching the fixer
- **Hosting**: tars / dedicated EC2 → compose sidecars. ECS → extra containers in the jobs task definition with a task-level shared volume

### Naming (matches tars: `<app>-app` / `-jobs` / `-db`)

Explicit `container_name` on every service, so there are no compose `-1` suffixes and `docker ps` groups under one prefix:

| Service / container | Image |
|---|---|
| `pitcrew-app` | pitcrew (web) |
| `pitcrew-jobs` | pitcrew (GoodJob worker) |
| `pitcrew-db` | postgres:16-alpine (or the shared infra `postgres`; decide at milestone 7) |
| `pitcrew-ruby32`, `pitcrew-ruby33`, `pitcrew-ruby34`, `pitcrew-ruby40` | `ghcr.io/aaronmiler/pitcrew-resolver:ruby-X.Y` (ruby:X.Y-slim + Go resolver) |

Resolver names have no dots (compose service names double as DNS hostnames). All containers get the label `pitcrew.role=app|jobs|db|resolver`, so `docker ps --filter label=pitcrew.role=resolver` works.

## Value reporting (`/reports`)

For both you and the team: a page plus a copyable summary.

- **Exposure window** (median, per repo and overall): advisory published → detected → PR opened → merged
- **Head start vs GitHub Advisory DB**: `ghsa_reviewed_at − rubysec_committed_at` (when Dependabot would have known vs. when we did); negative values are shown honestly
- **Auto-fix rate**: auto-fixed vs needs_attention
- **Volume**: CVEs closed, PRs merged, repos covered, per week/month
- **Time saved (estimate)**: auto-fixes × configurable minutes per manual fix

## UI (minimal)

- Repos: installation repos with an enabled toggle and "Scan now"; ecosystem badges (green = Pitcrew can fix it, `Repository::SUPPORTED_ECOSYSTEMS`), repos with a supported ecosystem sorted first, the rest dimmed. Repo sync detects them in one GraphQL query per 25 repos (was 50; GitHub 502s on the bigger query) (`Github::DetectRepoFiles`: lockfile existence + `.ruby-version` text, no clone)
- Repo detail: findings, PR link + CI status, event timeline
- Advisories: list with the repos affected
- Credentials: CRUD (secret write-only)
- Settings: PR title template with a live preview. The PR body stays fixed (gem_audit's table); the title is re-rendered when an open PR gets new findings, and long `gems`/`ids` lists are truncated ("rack, rack-session +4 more")
- Reports

## Milestones

- [x] **0. Spike** (scratchpad script), 2026-11-21, Bundler 2.6.9 / Ruby 3.4.9:
  - `bundle lock --update rack --conservative` cleared rack's advisories in ~0.6s with **zero gems installed**; other gems didn't move
  - `--patch` (3.1.0 → 3.1.24) cleared them as well as `--minor` (→ 3.2.9) → **try `--patch` first, escalate to `--minor`** (smaller than gem_audit.rb's minor-only)
  - A Gemfile `ruby "x.y.z"` mismatch does **not** block `bundle lock`, and is **not** honored in resolution: `ruby "2.7.8"` still locked nokogiri 1.19.7 (requires `>= 3.2`). Resolution follows the *running* Ruby → we need one Ruby per **minor** line (later decided: resolver sidecars, not mise) (`required_ruby_version` constraints are minor-level in practice)
- [x] **1. Skeleton**: from sapling (`git archive HEAD` + `bin/rename_app`); GoodJob; models + migrations (incl. `Setting`); 59 model specs green 2026-11-21
- [x] **2. GitHub App**: JWT → installation token client; OAuth login (initial-user bootstrap, invited users, allowed orgs); Access API (React screen in 5); repo inventory sync (hourly). 99 specs green; real sign-in and sync verified against the live App 2026-11-21 (53 repos, all created disabled)
- [x] **3. Advisories + scan**: advisory DB sync/import, GHSA enrich, scanner; specs on fixture lockfiles. 123 specs green 2026-11-21. Verified on aaronmiler/esther: 65 open findings across 17 gems, identical to the `bundle audit` CLI once its per-platform duplicates are collapsed (CLI prints 71: nokogiri 3 advisories × 3 platform builds). Notes: a scan fetches the lockfile via the API every 15m and skips when its blob sha is unchanged (no separate RepoSyncJob); the repo's `config/bundler-audit.yml` / `.bundler-audit.yml` ignore list is honored; GitHub dates are fetched only for advisories new after the first import; runtime image now includes `git`
- [x] **4. Fixer + PRs**: resolver sidecar + `Resolver::Client`; clone/resolve/re-audit/commit/push; PR open/update/close; PR sync. End-to-end against a throwaway repo pinned to an old vulnerable gem. 182 specs green. Verified end-to-end on aaronmiler/pitcrew-sandbox 2026-11-22: PR #1 by `a-pitcrew[bot]` (Verified commit, `Gemfile.lock` only) fixed 46 of 47 advisories across 6 gems (Rails family → 8.1.4.1 with rails-html-sanitizer 1.7.2; rack-session escalated to 2.1.2); rack-proxy flagged with its Gemfile reason. After merging: PR sync recorded the merge and deleted the branch, the next scan resolved all 46 (events: 47 detected, 46 pr_opened, 46 merged, 46 resolved, 1 needs_attention). sidecars verified live (3.3.14 / 3.4.13; a real resolve of the sandbox moved actionpack/actionview/activesupport to 8.1.4.1 with rails-html-sanitizer 1.7.2 in one call, `BUNDLED WITH` untouched). Decisions made while building:
  - **No `git push`.** The checkout is a read-only shallow clone (token via `GIT_CONFIG_*` env, never argv or `.git/config`). Commits go through the Git Data API, signed/Verified as the App's bot. **Revised 2026-11-22** (an update built on main's tree silently reverted commits people pushed to esther's PR branch): new PR = default head's tree + our `Gemfile.lock`, parent default head; update = clone the PR branch, tree = PR head's tree + our `Gemfile.lock`, parent PR head, ref moved fast-forward only (a mid-run push fails the update instead of being lost). The default branch is merged into the PR branch via GitHub's merges API only when its `Gemfile.lock` changed; a conflict raises for a person. Only `pitcrew/*` refs are written (guarded in code). `FixPullRequest.head_sha` is the head Pitcrew last left the branch at (set by each fix run, not by the PR poll); the 5-minute poll queues a forced fix when GitHub's head differs, i.e. someone pushed
  - **Closing a PR without merging = a human's no.** Its findings become `needs_attention` and the resolver skips those advisories from then on, so a new PR doesn't sneak them back in
  - A finding in a merged PR stays `in_pr` until the next scan sees the new lockfile and resolves it
  - Scan → fix trigger: open findings; or an open PR plus a changed default lockfile (forced refresh, merges the default branch in) or resolved findings (may close the PR)
  - The installation token is sent to the resolver as `BUNDLE_GITHUB__COM` for private `github:` gem sources. The repo's Gemfile runs there and could read it; acceptable since the repos are ours and the token is short-lived and installation-scoped
  - Deferred: the `required_ruby_version` safety net (resolution already runs on the repo's Ruby minor, so a mismatch needs a patch-level Ruby constraint)
- [ ] **5. UI**: Repos, Repo, Advisories, Access, Settings pages (Tailwind; livery theme landed 2026-11-23) + their API endpoints. Written 2026-11-22. No background polling (refresh after your own actions or via Refresh buttons); no retry action for needs_attention findings yet; no frontend test runner (API request specs + typecheck + a click-through)
- [x] **5.5. Keep current**: keep listed tooling gems (e.g. brakeman, whose `--ensure-latest` fails CI the day a release ships) at their latest release, in the same one PR per repo. Built 2026-11-22; specs green, verified live on aaronmiler/esther #2 (brakeman 8.0.5 → 8.1.1 committed on top of a human revert). Plan:
  - `Setting.keep_current_gems` (string array, empty by default; edited in Settings) and `Setting.tooling_pr_title_template` (default `chore(deps): update %{gems}`; same fields as `pr_title_template`). The security template is used whenever the PR fixes an advisory; the tooling one when it only bumps kept-current gems
  - `GemRelease` (`name` unique, `version`, `checked_at`): `GemReleasesJob` (hourly, and on saving the setting) reads rubygems.org `/api/v1/versions/<gem>/latest.json`. On a new version, enqueue FixRepositoryJob for enabled repos that are behind
  - `Repository.locked_versions` (jsonb, name → version), written by each scan, so "behind" needs no clone. Scan → fix trigger gains: any kept-current gem behind
  - Fix: after the advisory passes, one more resolve of the behind gems (+ exact-pin families) with no level flag (`bundle lock --update <gems> --conservative`): latest the Gemfile allows. Short of latest → noted in the PR body with the Gemfile requirement, nothing flagged
  - `GemBump` (repository, fix_pull_request, `gem_name`, `from_version`, `to_version`; unique per PR + gem): the kept-current record, separate from findings so CVE value reporting stays about CVEs. An open PR that already bumps every behind gem to latest counts as up to date. A PR closed without merging declines that version: the gem is skipped until a newer release
  - The tooling-only PR keeps the `pitcrew/security-*` branch name (it can gain advisories later); "nothing left" closing counts bumps too
  - Resolver accepts `level: "latest"` (no `--patch`/`--minor` flag)
  - Commit messages: a new PR's first commit carries the PR title; an update says what it adds (`Update: patch CVE-… in rack; brakeman 8.1.0 → 8.1.1`; merges of the default branch are GitHub's own commits). An update whose tree matches the PR head's commits nothing (title and body still refresh)
- [ ] **6. Reports**
- [ ] **7. tars stack**: tars owns the compose file; Pitcrew publishes images and documents running them (README → Deployment: images, example compose, env, GitHub App permissions)
  - [x] CI publishes `ghcr.io/aaronmiler/pitcrew` (`:latest`, `:<sha>`) and the resolver matrix after every check passes on `main`; the Go resolver has its own CI job (`gofmt`, `go vet`, `go test`), also in `bin/ci`
  - [x] GoodJob mode by env: a dedicated `good_job start` container from the same image (tars), or `GOOD_JOB_EXECUTION_MODE=async` in the web process
  - [ ] Push; first images published
  - [ ] tars compose entry (`pitcrew`, `pitcrew-jobs`, resolvers on an internal network, shared `/work` volume, shared infra Postgres via `DATABASE_URL`), `.env` (by hand), App callback URL, proxy route
  - [ ] `tars deploy pitcrew`; verify boot, first advisory sync, resolvers reachable; stop local `bin/dev` cron
  - [x] Per-repo `ruby_minor` (repo page select) for repos with no `.ruby-version`, e.g. gems; fallback only, a declared `.ruby-version` wins
  - [x] Scans skip until the first advisory sync has cloned the DB (that sync rescans everything); `/work` created owned by uid 1000 in both images

### JS phases (after Ruby is live)

Yarn v1 (`yarn.lock` v1, `packageManager: yarn@1.22.22` in sapling). The `dependencies`/`devDependencies` split is clean in sapling-based repos and mixed in older ones.

- [ ] **JS-1. Scan + classify (no PRs)**: parse `yarn.lock` + `package.json`; query the OSV.dev batch API for npm advisories; mark each finding `applicability` = shipped / build_only / unknown, from (a) which root it's reachable from (dependencies vs devDependencies) and (b) advisory hints (CWE, Node-only/dev-server wording). A mixed repo leans `unknown` rather than guessing. Report line: "N JS CVEs triaged as not shipped"
- [ ] **JS-2. Bundle membership**: `vite build --sourcemap` in the clone and read the sourcemap `sources` for `node_modules/<pkg>/` → definitive shipped / not shipped. Needs Node in the image
- [ ] **JS-3. Auto-PR for shipped only**: `yarn upgrade` within ranges first; transitive fixes need `resolutions` in package.json (a manifest edit, unlike Ruby; decide then)

### Folding in an ecosystem

Written 2026-11-22 so JS work starts with a map, not a refactor plan. Don't build the
abstraction before the second ecosystem: extract it with npm in hand.

Already neutral: `Repository.ecosystems` / `runtimes`, the resolver contract
(`/resolve/<ecosystem>`, sidecars picked by `[runtime, minor]`), the Resolvers panel, the
PR machinery (one PR per repo, branch-head builds, head tracking, default-branch merge),
findings and `finding_events`.

Ruby-specific today, and what each becomes:

| Where | Today | With a second ecosystem |
|---|---|---|
| Advisories | ruby-advisory-db sync | a source per ecosystem (npm: OSV or GitHub's advisory database); `ecosystem` column on advisories + findings, default `bundler` |
| Lockfile parsing | `Lockfile::Audit` / `Versions` / `Targets` | the same three operations per ecosystem |
| Scan | reads `Gemfile.lock` | loops over the repo's `ecosystems` |
| Fix | `Gemfile.lock` path, patch → minor levels, "only Gemfile.lock changed", `BUNDLE_*` credentials | each from the ecosystem |
| Commit | `CommitLockfile` writes one path | a list of paths: one PR can carry `Gemfile.lock` and `yarn.lock` |
| `locked_versions` | flat name → version | keyed by ecosystem (a gem and an npm package can share a name) |
| Keep current | rubygems.org, `GemRelease`, `GemBump` | a release source per ecosystem |
| Credentials | `GemSourceCredential` → `BUNDLE_<HOST>` | an ecosystem column; npm → `NPM_CONFIG_*` / `.npmrc` |
| Resolver | `bundler` entry in `resolver/ecosystems.go`, Ruby images | `npm` / `yarn` / `pnpm` entries; one Node image per Node major (`BASE=node:22-slim`), serving all three. Block `NODE_OPTIONS`; npm has no `--patch`, so the handler takes exact target versions |

Sketch: one small adapter per ecosystem (`Ecosystems::Bundler`, later `Ecosystems::Npm`)
providing its lockfile path, parse/audit/targets, levels, runtime, and credential env;
scan, fix, and commit loop over a repo's ecosystems.

## Open

- rails-toolkit gem-audit: retire or keep as a fallback