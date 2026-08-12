# Appresize Backlog

Last reviewed: 2026-08-12

This backlog favors small, native macOS improvements over new frameworks or broad feature expansion.

## Now

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
- [x] T2 — Show the default move and resize modifier chords in clearly labeled shortcut groups.
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

Evidence: launch policy and UI wiring are covered statically and by focused tests. A live installed-build launch presented Settings, the permission warning, and the System Settings fallback correctly; login-item launch plus grant/revoke transitions remain unchecked.

## Next

### AR-005 — Apply native Settings and menu polish

- Status: In progress — keyboard, VoiceOver, and Accessibility Inspector checks remain
- Priority: P1
- Dependencies: None

The existing AppKit interface should follow current macOS naming, keyboard, and accessibility conventions.

#### Implementation tasks

- [x] T1 — Rename `Preferences…` to `Settings…`, wire the existing Command-Comma item, and title the window `Appresize Settings`.
- [x] T2 — Remove irrelevant document-template menus and disable minimize for the Settings window.
- [x] T3 — Display modifier keys as `⌘`, `⌥`, `⌃`, `⇧`, and `fn` in clearly labeled Move and Resize groups.
- [x] T4 — Replace conflict-only beeps with the inline message `Move and Resize modifiers must differ.`
- [x] T5 — Replace the mouse-only GitHub field with a keyboard- and VoiceOver-accessible link.
- [x] T6 — Add standard `About Appresize` and `Report an Issue…` commands using existing app metadata and URLs.

#### Acceptance criteria

- [x] AC1 — Command-Comma opens Settings from an active Appresize process.
- [ ] AC2 — Every Settings control and link is reachable and understandable with keyboard navigation and VoiceOver.
- [x] AC3 — Invalid modifier combinations explain how to recover.

Evidence: a hosted-app test invokes the Command-Comma menu item and verifies the Settings window opens; both XIBs compile and Debug/Release builds pass. Live accessibility-tree inspection confirmed labels and help text for every control and link, and live modifier changes confirmed immediate shortcut-copy and inline-conflict updates. Keyboard traversal, VoiceOver, and Accessibility Inspector checks remain.

#### Definition of Done

- [ ] DOD1 — The Settings window is checked with Accessibility Inspector.
- [x] DOD2 — The README screenshot reflects the shipped interface.

## Later

### AR-008 — Strengthen release metadata and compatibility

- Status: In progress — release-workflow execution on the current revision remains
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
- Dependencies: None

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
