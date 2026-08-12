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

### AR-011 — Commit window frames on a timer instead of inside the event-tap callback

- Status: Done
- Priority: P1
- Dependencies: None

Reverse-engineering HyperDock's `HDWindowDragHelper` shows its smoothness comes from decoupling input sampling from Accessibility writes. Its HID event callback performs only float math and stores a `windowMovementTargetRect`; a `dispatch_source` timer (requested 5 ms interval, 1 ms leeway — requested cadence, not a guaranteed rate) on a global concurrent queue dirty-checks the target against `windowMovementLastCommittedRect` and issues at most one `AXUIElementSetAttributeValue` per changed component. Appresize currently calls `window.setOrigin`/`window.setSize` synchronously inside the CGEventTap callback (`Tracker.move(to:)`/`resize(delta:)` in `Appresize/Tracker.swift`). A slow target app blocks the callback, events back up at the HID tap, and macOS disables the tap after about a second — the failure the `tapDisabledByTimeout` re-enable path and `maxEventAbsorptionTime` watchdog currently compensate for.

#### Implementation tasks

- [x] T1 — Add `targetOrigin`/`targetSize` (or a single `targetRect`), `lastCommittedRect`, and a `generation` counter to `TrackingInfo` (`Appresize/TrackingInfo.swift`); `move(to:)`/`resize(delta:)` update only the target fields and keep all existing math (display constraints via `constrainedOrigin`, corner handling, minimum-size clamping). All of these fields are guarded by the state lock defined in T3 — `generation` included; no field is a loose atomic.
- [x] T2 — Add a `DispatchSourceTimer` (5 ms interval, 1 ms leeway) started in `startTracking(at:state:)` and cancelled in `resetTrackingState()`; its handler snapshots state and enqueues commit work only when the target rect differs from the last committed rect (a fast path only — the authoritative duplicate check is at write time, T3c); the commit queue calls `TrackingWindow.setOrigin`/`setSize` for changed components and records the committed rect under the state lock.
- [x] T3 — Make the state thread-safe without ever blocking the callback on AX. Three separate mechanisms — do not conflate them: (a) a state lock guarding `TrackingInfo`: the event callback mutates the target rect under this lock, performs no AX calls, and never dispatches synchronously to the commit queue; (b) the timer tick: acquires the state lock, copies an immutable snapshot (window, target rect, generation), releases the lock, and enqueues the commit work — it never performs AX inline; (c) a single serial commit queue: the only place AX writes execute, and the source of FIFO ordering. Each enqueued commit, immediately before its AX call and under the state lock, validates cancellation and generation AND re-checks its snapshot rect against the current `lastCommittedRect`, skipping the write when equal — two ticks can snapshot the same target while a prior commit is still queued, so snapshot-time checking alone permits duplicate writes. After writing, it records `lastCommittedRect` under the state lock only if the generation is unchanged. Every `generation` access — increment, snapshot read, pre-write validation — happens under the state lock. The invariant: a slow AX write may occupy the commit queue but must never block the event callback or the state lock.
- [x] T4 — Generation and ordering protocol: increment `generation` in `startTracking` only, under the state lock (not in reset). `resetTrackingState()` captures the final-commit snapshot under the state lock, enqueues an UNCONDITIONAL final commit on the commit queue (never generation-aborted: it is the ended drag's authoritative last write and always supersedes any in-flight tick for that drag), cancels the timer, then clears state under the lock. Cancel the timer before clearing `trackingInfo.window`.
- [x] T5 — Remove the `moveFilterInterval`/`resizeFilterInterval` time throttles; the timer is the throttle. Keep the `lastEventTime` absorption-watchdog behavior unchanged.
- [x] T6 — The final commit is dispatched to the commit queue; the event callback never waits for it (the window settles within one tick of release). Commit failures must reset tracking state exactly as write failures do today (including the main-thread hop for `Tracker.disable()` on permission loss).

#### Acceptance criteria

- [x] AC1 — During an active move/resize, the event-tap callback performs no `AXUIElementSetAttributeValue` calls; all AX writes originate from the commit queue (timer tick or enqueued final commit), never from the callback.
- [x] AC2 — A slow or hung target app no longer triggers tap-disabled-by-timeout during a drag (the callback cannot block on AX).
- [x] AC3 — No AX write is issued for a rect equal to the current `lastCommittedRect` at write time — including when two ticks enqueue the same target before the first commit runs (duplicate suppression happens at write time under the state lock, not only at snapshot time).
- [x] AC4 — The window keeps up with fast mouse movement, and the final frame matches the cursor position at modifier release.
- [x] AC5 — A stale commit that has not yet started its AX write never starts (cancellation and generation are validated on the commit queue immediately before the AX call). A commit already inside the AX write may land late; because commits are serialized on one queue, it is always followed by the ended drag's unconditional final commit, so the window settles at the final target rect even across an immediate reset or new drag. Demonstrated by deterministic gated-commit tests (blocked tick vs reset vs new drag) plus a TSAN-clean stress run.

#### Definition of Done

- [x] DOD1 — `AppresizeTests/TrackerTests.swift` gains coverage: commits are dirty-checked, two enqueued duplicates of one target produce exactly one AX write, the final commit fires on stop, timer failure resets state, and the blocked-tick-vs-reset race is exercised. Follow the existing `makeTracker(window:)`/`FakeWindow`/injectable-`now` pattern; make the timer and commit gate injectable via `Tracker.Dependencies` so tests stay deterministic.
- [x] DOD2 — No new framework, runloop, or process is introduced.

Evidence: all 71 unit tests pass. Deterministic Tracker tests cover dirty checks, queued duplicate suppression, asynchronous final/failure handling—including a failed tick suppressing its already-queued final retry—and blocked tick/reset/new-drag ordering; the three concurrency race/stress cases also pass with Thread Sanitizer enabled.

### AR-012 — Remove per-event AX read-back verification during drags

- Status: Open
- Priority: P1
- Dependencies: AR-011

HyperDock writes `AXPosition`/`AXSize` fire-and-forget and never reads the frame back mid-drag; it trusts its own computed rect and lets the next mouse event re-anchor (it computes from `moveResizeInitialWindowRect` + absolute displacement from drag start, so app-side clamping self-corrects on the next event). Appresize verifies every write with blocking reads: `move(to:)` does `setOrigin` → `origin()`; `resize(delta:)` does `setSize` → `size()` → `setOrigin` → `origin()` — up to four synchronous AX round-trips per commit. Appresize already computes from `initialOrigin`/`initialLocation`, so the read-backs buy nothing during an active drag.

#### Implementation tasks

- [ ] T1 — In the commit path (the timer tick after AR-011), drop the `window.origin()`/`window.size()` read-backs; use the write's `AXError`-backed `Bool` return as the only failure signal.
- [ ] T2 — Keep `trackingInfo.origin`/`size` advancing from the requested (math) values, not applied values; remove the `appliedOrigin`/`appliedSize` adjustment logic that only existed to honor read-back results.
- [ ] T3 — Preserve the existing native-minimum-size clamp behavior: resizing a window with a minimum size must still stop at the clamp rather than jitter or run away (the clamp is enforced by the app's AX server; our requested rect may exceed it — confirm the visual result stays pinned).

#### Acceptance criteria

- [ ] AC1 — No `AXUIElementCopyAttributeValue` for position/size occurs during an active drag.
- [ ] AC2 — A failed write (non-`.success`) still aborts the operation and resets state.
- [ ] AC3 — Resizing a minimum-size window does not jitter or run away.

#### Definition of Done

- [ ] DOD1 — Existing `TrackerTests` resize/clamp cases pass with read-back removed; tests asserting applied-vs-requested rect behavior are updated to the trust-and-commit contract.

### AR-013 — Replace the AX hit-test with CGWindowList + AX match-by-frame

- Status: Open
- Priority: P1
- Dependencies: None

HyperDock never calls `AXUIElementCopyElementAtPosition`. Its `+[OCWindow windowUnderMouse]` hit-tests with `CGWindowListCopyWindowInfo` (fast, pure CoreGraphics), then resolves the AX element once per drag: `AXUIElementCreateApplication(ownerPID)` → copy `AXWindows` → match candidates by position/size with a title fallback. Appresize's `AXUIElement.window(at:)` (`Appresize/AXUIElement+ext.swift`) uses the systemwide `AXUIElementCopyElementAtPosition` with a 0.5 s messaging timeout on the event-tap thread at every drag start — the slowest AX entry point and the one most prone to stalling on hung apps.

#### Implementation tasks

- [ ] T1 — Implement a CGWindowList hit-test: `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`, front-to-back order, layer 0, skip our own PID and windows without bounds; return the frontmost window containing the point.
- [ ] T2 — Resolve the AX element from the CG result: `AXUIElementCreateApplication(pid)`, bounded `AXUIElementSetMessagingTimeout` (~0.5 s), copy `AXWindows`, match by frame equality within a small tolerance (±2 px); fall back to a title match, then to the current `AXUIElementCopyElementAtPosition` path only if both fail.
- [ ] T3 — Surface the result as the existing `TrackingWindow` so `Tracker` is untouched; keep the current "unsupported window returns nil" behavior for non-participating apps (README's Known Limitations).

#### Acceptance criteria

- [ ] AC1 — Drag start no longer calls `AXUIElementCopyElementAtPosition` on the happy path.
- [ ] AC2 — Starting a drag over a hung app fails fast (bounded by the explicit messaging timeout) instead of stalling the tap.
- [ ] AC3 — The matched window set matches today's (normal document/app windows); windows the current code rejects still return nil.

#### Definition of Done

- [ ] DOD1 — CG→AX matching (tolerance, title fallback, nil cases) is unit-tested with synthetic window-info fixtures; the CGWindowList query is isolated behind a small function so tests can stub it.

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

### AR-014 — Round mouse deltas to float precision

- Status: Done
- Priority: P2
- Dependencies: None

HyperDock converts mouse deltas double→float→double inside its move/resize handlers, dropping sub-pixel precision before applying them. Appresize applies full double-precision deltas from `trackingDelta(at:)`, so high-resolution input devices emit fractional positions and sizes that AX servers round anyway; quantizing the target rect achieves the same stability with a stronger, testable guarantee.

#### Implementation tasks

- [x] T1 — Quantize the computed target origin and size to integral points where the target rect is stored (`Tracker.move(to:)` / `resize(delta:)`), keeping deltas themselves at full precision. Quantizing the accumulated target — not each delta — means slow sub-pixel motion still accumulates and steps by 1 px when it crosses a boundary. Note: a double→float→double round-trip (HyperDock's mechanism) drops precision but does NOT quantize (100.1 stays fractional); it is not an acceptable substitute.
- [x] T2 — Confirm rounding composes with the existing `Delta` accumulation and display-constraint math (no drift from repeated rounding).

#### Acceptance criteria

- [x] AC1 — Committed AX writes carry integral origins and sizes (rounded when the target rect is computed), and sub-pixel mouse noise alone never triggers an AX write.
- [x] AC2 — Slow, small movements still accumulate and apply (quantization must not swallow sub-threshold motion over time).

#### Definition of Done

- [x] DOD1 — A `TrackerTests` case feeds sub-pixel deltas and asserts both the rounding and the no-drift accumulation.

Evidence: all 40 `TrackerTests` pass. Focused move and resize cases verify sub-pixel noise produces no write, accumulated motion crosses the rounding threshold without drift, committed origins and sizes are integral, and moving a fractionally sized window does not resize it.

### AR-015 — Run the event tap on a dedicated high-priority thread

- Status: Done
- Priority: P2
- Dependencies: None

HyperDock creates its event tap on a dedicated `NSThread` (`threadPriority = 1.0`) and attaches the tap's runloop source to that thread's runloop, so main-thread work never delays event handling. Appresize attaches the tap to the main runloop in `enableTap()` (`CFRunLoopAddSource(CFRunLoopGetCurrent(), …)` called from `Tracker.enable()`); menu tracking, the Settings window, or any main-thread stall delays the callback. After AR-011 the callback is cheap, so this is polish — but it also isolates the app from future callback regressions.

#### Implementation tasks

- [x] T1 — Create and start the tap on a dedicated thread with elevated priority; keep `Tracker.shared` lifecycle and state mutations serialized (define and document which queue/thread owns `currentState`, `trackingInfo`, and cursor changes — today everything implicitly happens on main; align with the AR-011 locking/snapshot protocol).
- [x] T2 — Keep `Tracker.enable()`/`disable()` callable from the main thread; the `installEventTap == false` test path must remain main-thread-only.
- [x] T3 — Preserve the `tapDisabledByTimeout` re-enable behavior on the tap thread.

#### Acceptance criteria

- [x] AC1 — The tap callback never executes on the main thread (assert via `Thread.isMainThread` in a debug check or test hook).
- [x] AC2 — Enabling/disabling from the status menu and Settings remains race-free; no crash on rapid toggling.
- [x] AC3 — Opening the Settings window or tracking a menu during an active drag does not delay window commits.

#### Definition of Done

- [x] DOD1 — Threading ownership is documented in `Tracker.swift`; existing tests pass unchanged.

Evidence: all 75 unit tests pass unchanged and the Release build succeeds. Live Debug-build checks confirmed rapid Enabled toggling, responsive move/resize while opening Settings and tracking the status menu, and no callback-on-main assertion failure.

### AR-016 — Repost a synthetic mouseMoved when consuming drag events

- Status: Open
- Priority: P2
- Dependencies: None

While HyperDock consumes drag events during an active operation, it reposts an equivalent `mouseMoved` (`CGEventCreateMouseEvent` + `CGEventPost`) so the target app keeps receiving hover and cursor updates. Appresize swallows consumed events (returns nil from `myCGEventCallback`), so hovered UI in the target app freezes mid-drag.

#### Implementation tasks

- [ ] T1 — When `handleEvent` absorbs a `*MouseDragged` event during an active move/resize, post a synthetic `mouseMoved` at the same location (preserving relevant modifier flags) via `CGEventPost`.
- [ ] T2 — Guard against re-entry: the synthetic event flows through our own tap; it must not start a new tracking cycle or recurse (state is already active — verify `startTracking` cannot re-trigger, and add a regression test).
- [ ] T3 — Post only while an operation is active; never when idle.

#### Acceptance criteria

- [ ] AC1 — During a drag-activated resize, the target app's hover feedback (cursor shape, hover highlights) continues to update.
- [ ] AC2 — No event recursion or duplicate tracking starts; idle behavior unchanged.

#### Definition of Done

- [ ] DOD1 — A `TrackerTests` case asserts the synthetic post occurs only in the active-absorb path (inject the post function through `Tracker.Dependencies` for testability).

### AR-017 — Observe flagsChanged for keyboard-first activation

- Status: Open
- Priority: P3
- Dependencies: None

HyperDock's tap mask includes `keyDown`/`keyUp`/`flagsChanged`, so modifier transitions are evaluated the moment the chord is pressed or released — "press the shortcut, then move the mouse" is a first-class transition. Appresize infers state exclusively from mouse-event flags, so every transition waits for the next mouse event; a click that arrives immediately after releasing the chord can still be absorbed as part of the operation. Adding keyboard events routes every keystroke through our callback — scope this to `flagsChanged` only (modifier transitions carry no text input) and never consume keyboard events.

#### Implementation tasks

- [ ] T1 — Add `flagsChanged` to the tap mask in `enableTap()`; in `handleEvent`, treat it as a pure state re-evaluation (start/stop/transition exactly as a `mouseMoved` at the current location would) and always pass it through.
- [ ] T2 — Obtain the cursor location for activation from the flagsChanged event's `CGEvent.location` (it carries the cursor position) or `NSEvent.mouseLocation`; confirm the coordinate space matches the tap's.
- [ ] T3 — Keep keyboard events unconsumed in all paths; add a test asserting flagsChanged is never absorbed.

#### Acceptance criteria

- [ ] AC1 — State transitions (start/stop/move↔resize) take effect on the key event itself: releasing the chord ends the operation immediately, and a click right after release is never misinterpreted as part of an operation.
- [ ] AC2 — No keyboard event is ever consumed or measurably delayed.

#### Definition of Done

- [ ] DOD1 — `TrackerTests` covers activation, deactivation, and move↔resize transitions driven purely by flagsChanged events.

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
