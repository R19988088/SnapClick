# Dock Preview Stability and Window Shake Design

## Goals

- Keep the Dock preview panel stationary while the pointer moves within an app icon or between adjacent icons.
- Switch previews only after the pointer enters the middle 70% of the target icon along the Dock's layout axis.
- Support an Aero Shake-style title-bar gesture that minimizes the other visible normal windows in the current Space.
- A second shake of the same kept window restores only the windows minimized by the first shake, including their previous front-to-back order.
- Keep pointer-event handling lightweight enough to run continuously without visible input latency.

## Dock Preview Switching

`FinderDockPreviewController` keeps the currently selected Dock app as a latched selection. For a bottom Dock, a candidate app becomes active only when the pointer's x coordinate is inside the candidate icon bounds after a 15% inset on the left and right. For a left or right Dock, the same rule applies to the y coordinate after a 15% inset at the top and bottom.

Moving within the current icon, through the gap between icons, or through the outer 15% of a neighboring icon does not change the latched app. While the app remains latched, the existing preview panel frame and pointer frame remain unchanged. Crossing into a target icon's middle 70% changes the latched app once, rebuilds the preview content, and anchors the panel to that target icon.

Leaving both the latched icon's expanded vicinity and the preview panel still hides the preview using the existing behavior. Clicking a Dock icon continues to use the real icon under the pointer and does not inherit the hover-switch delay.

## Window Shake Recognition

A dedicated `WindowShakeController` observes passive global left-mouse down, dragged, and up events. On mouse down it performs one Accessibility hit test and accepts the gesture only when the hit element belongs to the title-bar region of a standard window. The controller records the dragged window ID and then handles drag samples using only timestamp and point arithmetic.

A shake requires two deliberate horizontal back-and-forth cycles within a short gesture window. Each leg must exceed a minimum horizontal travel, reverse direction, and remain within a vertical tolerance. Slow drags, short jitter, primarily vertical motion, and gestures that start outside a title bar reset without action. One mouse-down sequence can trigger at most once.

The constants remain private implementation values, with focused tests covering the accepted gesture and the rejection cases. No polling timer or per-drag window enumeration is used.

## Minimize and Restore Session

On the first recognized shake, the controller obtains the current on-screen window list in front-to-back order and matches eligible windows to Accessibility windows. It includes visible, standard, minimizable windows in the active Space and excludes:

- the dragged window;
- windows that were already minimized;
- desktop, Dock, menu-bar, panel, utility, and transient windows;
- windows that cannot be matched or minimized reliably.

Before minimizing, the controller stores each affected window's stable window ID, Accessibility element, frame, and front-to-back rank. It then minimizes exactly those windows. The dragged window remains active.

When the same dragged window is shaken again, the controller restores only the stored session entries that still exist and still belong to the current Space. It does not restore windows that were minimized before the first shake. Restored windows keep their original frames, and their saved ranks are reapplied from back to front so the previous stacking order is reconstructed while the shaken window remains foremost. Closed or otherwise stale windows are skipped. The session is cleared after restoration.

If a different title-bar window is shaken while a restore session exists, it starts a new isolation operation only after the previous session is discarded; it never mixes two restore sets.

## Performance

- Dock mouse movement performs one existing Dock Accessibility hit test plus constant-time bounds checks; preview enumeration and thumbnail work run only when the selected app changes or the existing refresh interval requires content refresh.
- Window drag movement performs no Accessibility or Core Graphics queries after the initial title-bar/window identification.
- Window enumeration happens only when a completed shake minimizes or restores windows.
- Existing event taps stay passive so native mouse delivery and Dock behavior are not blocked.
- No new dependency, polling loop, background sampler, or speculative cache is introduced.

## Verification

- Add focused executable contract tests for the target-icon middle-70% rule, stationary panel behavior, shake recognition, false-positive rejection, and restore-session filtering.
- Run the existing Dock window-control contract script and related regression scripts.
- Run a Debug compile check.
- Build a signed Release app and `dist/SnapClick.dmg`, then verify the app signature, DMG integrity, and SHA-256 according to `AGENTS.md`.
- Runtime-check bottom and side Dock switching, magnification, multi-window previews, shake minimize/restore, pre-minimized windows, closed windows, multiple Spaces, and restored stacking order.
