# Appresize Backlog

Last reviewed: 2026-07-28

This backlog favors small, native macOS improvements over new frameworks or broad feature expansion.

## Now

### AR-001 — Harden move and resize event handling

- Status: Done
- Priority: P0
- Dependencies: None

The event tap should never interrupt a valid operation or consume input for a window it cannot change.

#### Implementation tasks

- [x] T1 — Treat the five-second safety cutoff as an inactivity timeout by refreshing it after handled events.
- [x] T2 — Check the required Accessibility attributes are settable before starting a move or resize.
- [x] T3 — Stop tracking immediately when an Accessibility write fails.
- [x] T4 — Read back applied origin and size after macOS clamps window geometry.

#### Acceptance criteria

- [x] AC1 — A continuous move or resize lasting longer than five seconds does not reset.
- [x] AC2 — Fixed-size, full-screen, and otherwise non-settable windows retain normal mouse input.
- [x] AC3 — Reversing direction after reaching a window's minimum size responds immediately.

#### Definition of Done

- [x] DOD1 — Focused regression tests cover timeout, non-settable attributes, failed writes, and clamped geometry.
- [x] DOD2 — Debug and Release builds succeed.

Evidence: 45 focused unit tests pass; Debug test build and universal Release build succeed.

### AR-002 — Make local release installation replacement-safe

- Status: Done
- Priority: P0
- Dependencies: None

The documented `copy:release` task can currently nest `Appresize.app` inside an existing installation.

#### Implementation tasks

- [x] T1 — Replace the current `cp -r` command with a macOS-native copy that updates the existing bundle without nesting it.
- [x] T2 — Keep the task non-interactive and safe to run repeatedly.

#### Acceptance criteria

- [x] AC1 — Running `task copy:release` twice leaves exactly one `/Applications/Appresize.app`.
- [x] AC2 — The installed app reports the version from the second build.

#### Definition of Done

- [x] DOD1 — The repeat-install behavior is verified locally.
- [x] DOD2 — README build instructions remain accurate.

Evidence: the native installer stages a fresh bundle, moves the previous installation to Trash, and rolls back on replacement failure. Two exact `/Applications` installs left one unnested, signature-valid Appresize 0.0.3 whose binary matches the second build.

### AR-003 — Add a native Enabled control to the status menu

- Status: In progress — runtime menu and VoiceOver checks remain
- Priority: P1
- Dependencies: None

Users need a quick way to suspend global window handling without quitting the app.

#### Implementation tasks

- [x] T1 — Add a checked `Enabled` item at the top of the status menu.
- [x] T2 — Connect it to the existing `AppStateMachine.toggleEnabled()` behavior.
- [x] T3 — Dim the status icon while paused or unavailable and keep permission messaging distinct.
- [x] T4 — Keep pause temporary unless a persistent setting is explicitly needed later.

#### Acceptance criteria

- [x] AC1 — Toggling `Enabled` immediately starts or stops event tracking.
- [x] AC2 — The menu state and status icon always reflect the actual tracker state.
- [x] AC3 — Re-enabling without Accessibility permission directs the user to the existing permission flow.

Evidence: state transitions and presentation policy are unit-tested; live menu presentation and VoiceOver remain unchecked.

#### Definition of Done

- [x] DOD1 — State transitions and menu presentation have focused tests.
- [ ] DOD2 — VoiceOver announces the status button and Enabled state clearly.

### AR-004 — Improve first-launch and login-item permission behavior

- Status: In progress — manual launch and permission-path checks remain
- Priority: P1
- Dependencies: None

Manual first launch should explain the utility briefly, while background login launch must remain silent.

#### Implementation tasks

- [x] T1 — Use the existing first-launch value to open Appresize Settings on the first manual launch.
- [x] T2 — Add one concise quick-start sentence showing the default move and resize modifier chords.
- [x] T3 — Add a `Grant Accessibility Access` action that invokes the native system prompt with the current System Settings fallback.
- [x] T4 — Suppress modal permission alerts when launched as a login item.

#### Acceptance criteria

- [x] AC1 — First manual launch presents Settings and explains how to try the core interaction.
- [x] AC2 — Granting permission activates tracking without requiring a restart when the event tap can be created.
- [x] AC3 — Login-item launch never steals focus or presents a modal alert.
- [x] AC4 — Missing permission remains visible through the status menu and Settings.

#### Definition of Done

- [ ] DOD1 — Manual launch, login launch, permission grant, and permission revocation paths are tested.
- [x] DOD2 — No onboarding wizard or additional framework is introduced.

Evidence: launch policy and UI wiring are covered statically and by focused tests; live manual/login/grant/revoke paths remain unchecked.

## Next

### AR-005 — Apply native Settings and menu polish

- Status: In progress — accessibility inspection and README screenshot remain
- Priority: P1
- Dependencies: None

The existing AppKit interface should follow current macOS naming, keyboard, and accessibility conventions.

#### Implementation tasks

- [x] T1 — Rename `Preferences…` to `Settings…`, wire the existing Command-Comma item, and title the window `Appresize Settings`.
- [x] T2 — Remove irrelevant document-template menus and disable minimize for the Settings window.
- [x] T3 — Display modifier keys as `⌘`, `⌥`, `⌃`, `⇧`, and `fn`, including a readable chord summary.
- [x] T4 — Replace conflict-only beeps with the inline message `Move and Resize modifiers must differ.`
- [x] T5 — Replace the mouse-only GitHub field with a keyboard- and VoiceOver-accessible link.
- [x] T6 — Add standard `About Appresize` and `Report an Issue…` commands using existing app metadata and URLs.

#### Acceptance criteria

- [x] AC1 — Command-Comma opens Settings from an active Appresize process.
- [ ] AC2 — Every Settings control and link is reachable and understandable with keyboard navigation and VoiceOver.
- [x] AC3 — Invalid modifier combinations explain how to recover.

Evidence: a hosted-app test invokes the Command-Comma menu item and verifies the Settings window opens; both XIBs compile and Debug/Release builds pass. Live keyboard traversal, VoiceOver, Accessibility Inspector, and screenshot checks remain.

#### Definition of Done

- [ ] DOD1 — The Settings window is checked with Accessibility Inspector.
- [ ] DOD2 — The README screenshot reflects the shipped interface.

### AR-006 — Reduce Accessibility polling and hot-path work

- Status: Done
- Priority: P1
- Dependencies: AR-001

Permission checks should remain safe without running a TCC query for every intercepted mouse event or maintaining three independent timers.

#### Implementation tasks

- [x] T1 — Keep one authoritative permission monitor.
- [x] T2 — Remove redundant Tracker and Settings polling.
- [x] T3 — Check trust in the event callback only when an operation may activate, while active, or when the event tap reports a special failure.
- [x] T4 — Propagate permission-state changes to the status menu and visible Settings window.

#### Acceptance criteria

- [x] AC1 — Ordinary mouse movement without configured modifiers does not query Accessibility trust.
- [x] AC2 — Revoking permission safely disables tracking within the monitor interval.
- [x] AC3 — Granting permission refreshes all visible UI and retries activation once.

#### Definition of Done

- [x] DOD1 — Permission transition tests cover grant, revoke, and event-tap disable paths.
- [x] DOD2 — Instruments or lightweight counters confirm the idle hot path no longer polls TCC.

Evidence: one common-run-loop monitor owns permission changes; pure transition tests cover grant, revoke, and unchanged state, Tracker tests cover event-tap disable, and injected counters prove idle events do not query trust.

### AR-007 — Add focused core behavior tests

- Status: In progress — CI confirmation remains
- Priority: P1
- Dependencies: AR-001, AR-004, AR-006

The Tracker state machine and launch behavior need deterministic coverage without creating a real system event tap.

#### Implementation tasks

- [x] T1 — Add the smallest test seam needed to run Tracker logic without Accessibility permission or a system event tap.
- [x] T2 — Cover idle-to-move, idle-to-resize, modifier release, operation switching, drag-only mouse-up, and timeout behavior.
- [x] T3 — Cover non-settable windows and failed Accessibility writes.
- [x] T4 — Make local test failure clear when another Appresize instance prevents the test host from launching.
- [x] T5 — Remove or replace the currently disabled launch test and the unused `TEST` compilation branch.

#### Acceptance criteria

- [ ] AC1 — Core event transitions run in CI without permission prompts.
- [x] AC2 — Local test output explains any running-app conflict instead of failing with an opaque LaunchServices error.
- [x] AC3 — Tests do not create a global event tap.

#### Definition of Done

- [ ] DOD1 — `task test:unit` passes locally with Appresize stopped and in CI.
- [x] DOD2 — The test seam remains internal and introduces no production abstraction beyond what tests exercise.

Evidence: `task test:unit` passes 45 tests; the XCTest host skips production services and Tracker tests use the no-tap seam. Preflight reports a running Appresize process explicitly.

## Later

### AR-008 — Strengthen release metadata and compatibility

- Status: In progress — implementation complete; current-revision CI execution remains
- Priority: P2
- Dependencies: None

Release artifacts should identify their contents correctly and support the widest macOS range the current APIs allow.

#### Implementation tasks

- [x] T1 — Fail release workflows when the tag or manual release version differs from `MARKETING_VERSION`.
- [x] T2 — Evaluate lowering the deployment target from macOS 15.2 to macOS 13.
- [ ] T3 — Smoke-test move, resize, Accessibility permission, and launch-at-login behavior on macOS 13 before changing the published requirement.

#### Acceptance criteria

- [x] AC1 — A mismatched release version cannot be published.
- [x] AC2 — The app builds universally for the selected deployment target.
- [ ] AC3 — The README and release notes report the tested minimum macOS version.

#### Definition of Done

- [ ] DOD1 — Tag, manual-release, and compatibility checks run in CI.
- [ ] DOD2 — Ventura runtime evidence is recorded before lowering the deployment target.

Evidence: tag/manual versions are gated before release; the current macOS 15.2 artifact builds for arm64 and x86_64. A macOS 14 target override fails because `NSCursor.frameResize` requires macOS 15+, so Ventura cannot run the current implementation. README and generated release notes consistently state macOS 15.2 or newer. Workflow YAML and version-gate behavior pass local validation; current-revision remote execution remains pending.

### AR-009 — Add restrained operation feedback and reachability guards

- Status: In progress — manual multi-display and cancellation checks remain
- Priority: P2
- Dependencies: AR-001

Window manipulation should communicate its active mode and avoid leaving windows unreachable.

#### Implementation tasks

- [x] T1 — Show a move cursor while moving and corner-appropriate resize cursors while resizing.
- [x] T2 — Restore the prior cursor on every reset, failure, and permission transition.
- [x] T3 — Keep enough of the title bar within a display's visible frame when moving.
- [x] T4 — Prevent invalid negative or effectively unusable requested dimensions.

#### Acceptance criteria

- [x] AC1 — Cursor feedback matches the active operation and selected resize corner.
- [x] AC2 — Cancelling or failing an operation never leaves a custom cursor active.
- [x] AC3 — Moving across multiple displays cannot make the entire title bar unreachable.

#### Definition of Done

- [ ] DOD1 — Multi-display, minimum-size, and cancellation behavior is manually verified.
- [x] DOD2 — No snapping, tiling, or layout engine is added.

Evidence: deterministic tests cover cursor restoration, display-coordinate conversion, cross-display boundaries, native minimum clamping, and failure cancellation; live multi-display verification remains.

## Deferred decision

### AR-010 — Sign and notarize public releases

- Status: Deferred — requires an Apple Developer Program decision
- Priority: P3
- Dependencies: AR-008

Developer ID signing and notarization would provide the standard Gatekeeper installation experience for direct downloads.

#### Implementation tasks

- [ ] T1 — Decide whether to join the Apple Developer Program for this project.
- [ ] T2 — Store signing and notarization credentials as protected CI secrets.
- [ ] T3 — Sign with Developer ID, submit with `notarytool`, staple the ticket, and verify the distributed DMG.

#### Acceptance criteria

- [ ] AC1 — A downloaded release opens through the standard Gatekeeper flow without quarantine-removal instructions.
- [ ] AC2 — CI verifies the Developer ID signature, hardened runtime, and notarization ticket.

#### Definition of Done

- [ ] DOD1 — Release and recovery procedures are documented without exposing credentials.

## Scope guard

Do not add a SwiftUI rewrite, window-snapping engine, updater framework, global-shortcut framework, app exclusion system, or preset system until a concrete user need justifies it.
