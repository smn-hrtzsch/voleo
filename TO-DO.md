# TO-DO

## In Progress

- [x] Configure Firebase project on Spark plan and add platform config files locally.
- [x] Replace local-first repository wiring with Firebase repository after config exists.
- [ ] Authenticate GitHub CLI and create private remote repository.
- [ ] Stabilize Firebase-backed app flow after enabling Firebase integration.
- [ ] Ensure tips are evaluated correctly and consistently for all users.
- [ ] Automatically update match results so points are recalculated from current results.
- [ ] Keep the friends league state correct and consistent across devices and sessions.
- [ ] Show other league participants' tips and points inside the league.
- [ ] In the match overview, show point breakdown details when a match is selected.
- [ ] Verify the end-to-end MVP on Pixel 7 before Thursday deadline.
- [ ] Fix endless loading indicator in the Heute tab after matches are visible.
- [ ] Fix match tip routing so matches can be tipped again.
- [ ] Fix Google sign-in failures after account selection.
- [ ] Fix endlessly loading Liga tab.
- [ ] Replace manual score text fields with vertical score pickers.
- [ ] Remove redundant "Anpfiff" label from match metadata.
- [ ] Design and implement a local-first sync architecture with Firestore as the cloud source of truth.
- [ ] Fix saved tips not appearing immediately in Heute and Spiele.
- [ ] Fix tip detail back navigation preserving the originating tab.
- [ ] Redesign Liga tips by day and player with visibility only after kickoff.
- [ ] Show other players' tips in match details only after kickoff.
- [ ] Improve profile layout, linked-provider feedback, profile image handling, and anonymous sign-out warning.
- [ ] Avoid onboarding flash for already signed-in users on cold start.
- [ ] Add Bosnia and Herzegovina flag aliases.
- [ ] Restructure Heute tab to show only today's matches plus league shortcut and top 3 standings.
- [ ] Generate league invite codes randomly instead of deriving them from user input.
- [x] Add league invite link/code handling for sharing and joining rounds.
- [ ] Limit Liga day sections to tournament days that have already started.
- [ ] Add an automatic tournament-phase filter that resets to the current phase on app restart.
- [x] Refresh profile name and profile image immediately after edits.
- [x] Enforce unique display names within a league.
- [ ] Default new score wheels to 0:0.
- [x] Always confirm sign-out, with stronger warning for anonymous accounts.
- [ ] Add a debug/test path for fake league members, fake tips, and synthetic match results.
- [ ] Explain and harden Firestore network/DNS error handling while connected to Wi-Fi.
- [ ] Replace old deterministic league codes like MEIN26 with migrated random invite codes.
- [x] Use real web invitation links that are linkified in messengers and route into the app.
- [x] Add invite-link handling for users who are already inside another league.
- [x] Allow users to join multiple leagues and switch the active league from Liga.
- [x] Give league owners admin controls such as renaming the league.
- [x] Show member profile images in league standings and tip views.
- [x] Add app theme settings for system, light, and dark mode.
- [x] Add Lieblingsmannschaft, Favorit, and Risiko-Tipp tournament picks and points scoring dynamics.
- [ ] Show flags consistently in the tip screen.
- [ ] Redesign Spiele tab with a Fotmob-inspired compact tournament match layout.
- [ ] Add a date-mode switch for games with swipe navigation and current-day initial focus.

## MVP

- [x] Create Flutter project foundation for Android and iOS.
- [x] Use package IDs `de.capycode.voleo`.
- [x] Add app shell, navigation, and MVP screens.
- [x] Add classic scoring engine.
- [x] Add unit tests for scoring, locking, and standings.
- [x] Add result-sync script with dry-run support.
- [x] Add GitHub Actions for CI and scheduled result sync.
- [x] Avoid duplicate and non-app CI runs after checked pull requests.
- [x] Add Firestore security rules foundation.
- [x] Add README, MIT license, and project tracking.
- [x] Persist local account and tips across app restarts.
- [x] Add full WM 2026 group-stage fixture fallback with date/group filters.
- [x] Merge OpenLigaDB match/result data into local fixture display.
- [x] Remove demo leaderboard users from the MVP league view.

## Later

- [ ] Add social feed, reactions, and comments.
- [ ] Add bonus questions for champion, group winners, and top scorer.
- [ ] Add push notifications for upcoming lock deadlines.
- [ ] Add tournament recap after the final.
