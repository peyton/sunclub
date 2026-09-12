# Sunclub

iOS sunscreen tracking app. Keep existing features, public automation routes,
platform targets, persisted identities, signing identifiers and recovery behavior.

## Commands and context

```sh
just bootstrap # When locked tools or Python dependencies need setup
just build     # Build the development simulator app
just run       # Build, install and launch the development app
```

Build/run use **SunclubDev**, Debug, iPhone simulator. Release uses **Sunclub**.
Generation is automatic. Bootstrap installs locked tools and Python dependencies;
optional local Tuist caching is `just cache-setup`.

Read linked documents only for the affected surface; this is not a startup checklist.

- Ownership or feature wiring: [architecture](docs/architecture.md).
- Build/test/tooling work: [commands](docs/commands.md).
- Data, accessibility or automation changes: the relevant [release gate](docs/release-gates.md).
- CI, signing or release work: [CI stability](docs/ci-release-stability.md).
- A matching build/tool failure: [historical troubleshooting](docs/development-troubleshooting.md).
- Public automation changes: [automation contract](docs/app-automation.md).
- UI changes: `DESIGN.md`, `AppDesignSystem.swift`; product behavior: `app/SPEC.md`.

## Task scope and skills

- These repository rules override conflicting skill workflow defaults. Use a
  skill when requested or when its concrete operation fits the task; incidental
  technology names, status words and task phases are insufficient triggers.
  Discover/install skills only when requested. Load supporting references as needed;
  do not start skill-loading chains for every task.
  Keep the existing stack unless a change is requested or necessary for the task;
  provider-specific workflows require the relevant provider/tool. Append terminology
  extras only when the user asks to identify a term.
- Complete authorized implementation, verification and delivery. Do not stop at
  a plan, first draft or integration menu when the user already requested the next
  step. Ask only for consequential missing information or authorization; preserve
  explicit user checkpoints, including selection among requested design options.
- Scale planning and review to the change. Routine edits do not require separate
  spec/plan files, a worktree or subagents. Diagnose and fix failures caused by the
  change, then rerun affected checks without asking again. Surface blockers that
  require user input while continuing independent authorized work.
- Keep tool permission boundaries and the release/data gates below. When new
  approval is needed, finish authorized preparation and present the concrete
  result before asking at the action that needs it.

## Working rules

- Swift 6 strict concurrency; 4-space indentation. Reuse existing protocols;
  inject external services and the clock through `SunclubAppDependencies`.
- `AppState` owns observable state and coordination. Shared writes belong in
  `SunclubMutationService` and revision-history services. Effects follow a
  successful changed receipt; automation authorization stays at its entrypoint.
- No new dependencies or framework/package layers merely for organization.
- Never change persisted fields without a new immutable versioned schema and
  prior-store migration tests. Every container uses `SunclubModelContainerFactory`.
- Preserve local and CloudKit history. Empty startup state must never replace
  meaningful history; reinstall restore fetches before publishing.
- Preserve the accessibility scorecard: named controls, Dynamic Type, sufficient
  contrast, non-color cues and Reduce Motion through `SunMotion`. UI tests keep
  `UITEST_MODE` and deterministic `UITEST_FORCE_*` arguments.
- New user features need App Intent and URL/foreground routes, with the foreground
  exceptions in the automation release gate. Add Settings controls for automation
  knobs, privacy toggles or sensitive callbacks; document/test affected automation.
  Keep legacy redirects and permission gates.
- Styling uses `AppDesignSystem.swift` and `AppTheme.swift`. Do not change visual
  direction as an incidental refactor. Generated artwork belongs to its generator.
- Specs, plans and tool documentation go in `docs/`, kept terse. No ticket IDs in
  document filenames or headers.
- Default to one PR per task; follow explicit delivery instructions within branch
  protections. Commits use `feat:`, `fix:` or `chore:` (`PER-XX:` for ticketed work).
  PR descriptions include verification.

## Verify

- Match checks to changed behavior: app work uses `just test-unit` and, for affected
  UI flows, `just test-ui-smoke`; scripts/metadata use `just test-python`; style and
  prose use `just ci-lint`. Prose-only edits do not need local Xcode builds/tests.
- `just ci` includes lint, Python, full unit/UI tests (including smoke), and both
  device builds. Reuse passing evidence for the unchanged candidate; do not rerun
  constituent checks at each workflow stage. Rerun when changes, failures or an
  unresolved concern invalidate that evidence. Add behavioral regression tests
  where useful; prose/configuration edits do not require a forced red/green cycle.
  Do not discard working changes merely to recreate a test-first chronology.
- CI/workflow edits require the closest local CI-equivalent check and passing
  expected GitHub jobs. Never infer readiness from skipped checks.
- Refactor/release candidates need full CI on the exact SHA. Only known web/docs
  PRs skip iOS; unknown changes run it. Preserve the required `CI` gate.
- Signing, store, import and sync changes must satisfy all
  [data release gates](docs/release-gates.md). Before trusting an upload, inspect
  final IPA entitlements and embedded watch diagnostics, not just profiles.
- App Review submission requires a dry run and review checkpoint before final
  submission. Complete authorized preparation before presenting that checkpoint;
  reuse approval only for the same reviewed package and action. See
  [App Store submission](docs/app-store-submission.md).
