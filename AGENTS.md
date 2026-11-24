# Pitcrew

Keeps Ruby dependencies free of known CVEs so `bundle audit` never blocks a deploy.
Polls ruby-advisory-db, scans selected GitHub repos, makes the smallest lockfile change
that clears each advisory, and opens one PR per repo. Replaces Dependabot.

`PLAN.md` holds the design, the decisions, and the milestone checklist. It's local only
(gitignored), so it may not exist in a fresh clone. When it does, read it before
non-trivial work and tick milestones off as they land.

Built from [sapling](https://github.com/aaronmiler/sapling). Style config (RuboCop,
Prettier) comes from [evergreen](https://github.com/aaronmiler/evergreen); change shared
rules there, not here.

## Invariants
- Never edit a target repo's Gemfile. Only its Gemfile.lock changes; a fix that needs a
  Gemfile change becomes a `needs_attention` finding.
- Resolve with `bundle lock --update <gem> --conservative`, `--patch` first, then
  `--minor`. Kept-current gems (`Setting.keep_current_gems`) get one more call with no
  level flag (latest the Gemfile allows). Never `bundle install` or `bundle update`
  against a target repo.
- Resolution runs in the resolver sidecar for the Ruby minor the checkout declares
  (`.ruby-version` on the branch being fixed), never in the app process: a Gemfile is
  executable code. A repo that declares none (e.g. a gem) uses the minor set on it in the
  UI (`Repository#ruby_minor`); a declared `.ruby-version` always wins. A missing resolver
  is a `needs_attention` finding, not a fallback to another Ruby.
- At most one open Pitcrew PR per repo, each on its own branch (`pitcrew.security-YYYYMMDD`,
  `-2` and up for a repo's second PR that day). A new PR builds on the default branch's
  head; an update builds on the PR branch's head, so people's commits on it carry forward
  (never main's tree + our lockfile: that silently reverted them). The default branch is
  merged in server-side only when its lockfile moved; a conflict stops for a person.
  Refs move fast-forward only, never force-pushed. Re-check the PR's state on GitHub
  before deciding to update it or open a new one; the DB copy can be stale.
- Pitcrew only creates, pushes to, or deletes its own branches: `pitcrew` plus one of
  `/ . - _` (`FixPullRequest::BRANCH_PREFIX`; the separator for new ones is a `Setting`).
- ruby-advisory-db is the detection source of truth; the `advisories` table indexes it.
- Gem source credentials live encrypted in the DB and reach the resolver per request as
  `BUNDLE_<HOST>` env. Never write them to a clone or a log.
- `finding_events` is append-only. Value reporting is built on it. Finding status changes
  only through `Finding#detect!` / `resolve!` / `move_to_pr!` / `flag!` / `merged!`, which
  write the event; never `update!(status:)` directly.
- Every GitHub call goes through a `Github::` service (`app/services/github/`, one per
  operation); nothing else touches Octokit. They return plain values, not Octokit
  resources, and every write checks `Github.ensure_pitcrew_branch!`.

## Conventions
- Jobs: GoodJob (cron in `config/initializers/good_job.rb`). No Sidekiq, no Redis.
- Auth: GitHub OAuth only, in the `Authentication` concern. Match users by `github_uid`;
  trust `github_login` only for a pending invite or the `PITCREW_INITIAL_USER` bootstrap.
- Config: anything editable lives in the DB and the UI (`Setting`, `GemSourceCredential`).
  Env is only for bootstrap (DB, encryption keys, GitHub App, `PITCREW_INITIAL_USER`).
- Services: `app/services/`, inherit `ApplicationService`, arguments to `.call`. Anything
  instantiated with `.new` is not a service and lives in `lib/`: values passed between
  services (`Fix::KeptGem`, `Lockfile::Change`, `Fix::Outcome`) and helpers like
  `Lockfile::Versions` and `PullRequestContent`. Values are plain classes (`attr_reader` plus
  a keyword `initialize`), not `Data.define` or positional arrays. `app/models/` is only
  DB-backed records.
- Style: no endless (one-line `def x = ...`) methods.
- Tests: RSpec + FactoryBot + shoulda-matchers. Stub GitHub/HTTP with WebMock; use
  fixture lockfiles in `spec/fixtures/lockfiles/`.
- Add an SPA catch-all route in `config/routes.rb` when client-side routes arrive (example comment there).

## Out of scope until asked
- LLM upgrade advice.
- JS/npm work beyond the phases listed in `PLAN.md`.
