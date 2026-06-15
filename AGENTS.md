# AGENTS.md

## Project Workflow

- Always check `git status` before making changes.
- Keep `TO-DO.md` updated for completed product or infrastructure tasks.
- Do not commit, push, open PRs, or merge unless Simon explicitly asks for it.
- Use feature branches for new work, for example `feat/admin-debug-screen`.
- Use Conventional Commits in English.

## Firebase Sync Operations

- `syncLiveResults` runs every minute and updates live match documents.
- `syncResults` runs hourly and performs a full match sync plus score audit.
- `settings/sync_status` stores the latest operational status:
  - `live`: latest minute sync result.
  - `full`: latest full sync result.
  - `scoreAudit`: latest scoring and standings audit.
- Live and full syncs must not downgrade better existing match data:
  - `finalResult` outranks `live`, which outranks `scheduled`.
  - Existing `football-data` live/final data must not be overwritten by weaker OpenLigaDB data.
  - Older `football-data` provider timestamps must not overwrite newer provider data.
- Recalculation deletes orphan tips whose `uid` is no longer a league member.

## Admin Debug Screen

- The admin debug screen is available at `/profile/admin-debug`.
- The profile entry point is visible only for Simon's Firebase UID.
- The screen reads `settings/sync_status` and is intended for matchday checks:
  - current live sync state,
  - full sync result,
  - score audit counts,
  - skipped stale updates,
  - latest errors.
- Firestore rules allow `settings/sync_status` only for the admin UID.

## Release / Merge Checklist

- Run `flutter test` before committing when Flutter code changes.
- Deploy or verify Firebase rules/functions when cloud behavior changes.
- After opening a PR, wait for the Flutter GitHub workflow/checks to finish successfully before merging.
- Merge with `gh pr merge` only after checks are green.
