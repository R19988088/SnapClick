# Dock Preview and Window Shake Implementation Plan

> **For the AI implementation agent:** Required sub-skill: use superpowers:executing-plans to implement this plan inline. Track each checkbox as work completes.

**Goal:** Keep Dock previews stationary with middle-70% target switching and add a fast, accurate title-bar shake gesture that minimizes and restores only the windows affected by the gesture.

**Architecture:** Put constant-time Dock geometry and shake gesture recognition in a small Foundation/CoreGraphics unit that can be exercised without launching the app. Keep Dock presentation changes in the existing `FinderDockPreviewController`. Add a dedicated passive `WindowShakeController` for Accessibility window identification and minimize/restore sessions, wired from `AppDelegate`.

**Tech stack:** Swift, AppKit, ApplicationServices Accessibility, CoreGraphics event taps, shell contract tests, Xcode build/signing tools.

---

## File Structure

- Create `SnapClick/Core/WindowInteractionGeometry.swift`: pure Dock hit-zone helpers and the horizontal shake recognizer.
- Create `SnapClick/Core/WindowShakeController.swift`: passive event tap, accurate title-bar/window matching, window snapshot, minimize, and restore ordering.
- Modify `SnapClick/App/AppDelegate.swift`: latch Dock hover selection, freeze panel geometry, expose the existing window-ID bridge, and start/stop the shake controller.
- Modify `SnapClick.xcodeproj/project.pbxproj`: include both new Core files in the SnapClick target.
- Create `scripts/test_window_interaction_geometry.swift`: executable behavior assertions for geometry and gesture recognition.
- Create `scripts/test_window_interaction_geometry.sh`: compile and run the focused assertions.
- Modify `scripts/test_dock_window_control.sh`: assert the latched Dock switching and shake-controller integration contracts.

### Task 1: Pure Dock Geometry and Shake Recognition

- [ ] **Step 1: Add the focused executable test with failing API references**

Create `scripts/test_window_interaction_geometry.swift` with assertions equivalent to:

```swift
import CoreGraphics
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let icon = CGRect(x: 100, y: 20, width: 100, height: 80)
expect(!dockTargetCoreContains(CGPoint(x: 114, y: 60), bounds: icon, axis: .horizontal), "left 15% must not switch")
expect(dockTargetCoreContains(CGPoint(x: 115, y: 60), bounds: icon, axis: .horizontal), "middle 70% must switch")
expect(dockRetentionContains(CGPoint(x: 80, y: 60), bounds: icon, axis: .horizontal), "20% side extension must retain")
expect(!dockRetentionContains(CGPoint(x: 79, y: 60), bounds: icon, axis: .horizontal), "outside 20% extension must hide")

var shake = WindowShakeRecognizer()
shake.begin(at: CGPoint(x: 0, y: 0), timestamp: 0)
expect(!shake.update(to: CGPoint(x: 60, y: 2), timestamp: 0.12), "first leg must not trigger")
expect(!shake.update(to: CGPoint(x: 0, y: -2), timestamp: 0.24), "second leg must not trigger")
expect(!shake.update(to: CGPoint(x: 60, y: 1), timestamp: 0.36), "third leg must not trigger")
expect(shake.update(to: CGPoint(x: 0, y: 0), timestamp: 0.48), "two back-and-forth cycles must trigger")

var jitter = WindowShakeRecognizer()
jitter.begin(at: .zero, timestamp: 0)
for index in 1...12 {
    expect(!jitter.update(to: CGPoint(x: index.isMultiple(of: 2) ? 20 : -20, y: 0), timestamp: Double(index) * 0.05), "short jitter must not trigger")
}

var vertical = WindowShakeRecognizer()
vertical.begin(at: .zero, timestamp: 0)
expect(!vertical.update(to: CGPoint(x: 60, y: 90), timestamp: 0.1), "vertical drag must reject")
```

Create `scripts/test_window_interaction_geometry.sh` to compile the production helper and test together into a temporary binary, run it, and delete it with a shell trap.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `bash scripts/test_window_interaction_geometry.sh`

Expected: compilation fails because `DockLayoutAxis`, `dockTargetCoreContains`, `dockRetentionContains`, and `WindowShakeRecognizer` do not exist.

- [ ] **Step 3: Implement the minimum pure helper API**

Create `SnapClick/Core/WindowInteractionGeometry.swift` with:

```swift
import CoreGraphics
import Foundation

enum DockLayoutAxis { case horizontal, vertical }

func dockTargetCoreContains(_ point: CGPoint, bounds: CGRect, axis: DockLayoutAxis) -> Bool {
    let insetFraction: CGFloat = 0.15
    switch axis {
    case .horizontal:
        return point.x >= bounds.minX + bounds.width * insetFraction
            && point.x <= bounds.maxX - bounds.width * insetFraction
    case .vertical:
        return point.y >= bounds.minY + bounds.height * insetFraction
            && point.y <= bounds.maxY - bounds.height * insetFraction
    }
}

func dockRetentionContains(_ point: CGPoint, bounds: CGRect, axis: DockLayoutAxis) -> Bool {
    switch axis {
    case .horizontal:
        return point.x >= bounds.minX - bounds.width * 0.20
            && point.x <= bounds.maxX + bounds.width * 0.20
    case .vertical:
        return point.y >= bounds.minY - bounds.height * 0.20
            && point.y <= bounds.maxY + bounds.height * 0.20
    }
}
```

Add `WindowShakeRecognizer` with private constants `minimumLegDistance = 50`, `maximumDuration = 1.0`, `maximumVerticalDrift = 70`, and `requiredLegCount = 4`. `begin` resets the start point, turning point, direction, leg count, and trigger flag. `update` rejects expired/vertical gestures, tracks the horizontal extreme in the current direction, counts a leg only after 50 points of opposite travel, and returns `true` exactly once after four qualifying legs.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `bash scripts/test_window_interaction_geometry.sh`

Expected: `Window interaction geometry tests passed`.

- [ ] **Step 5: Add both source files to the Xcode project as work progresses**

Add file references under the existing `Core` group and source build entries under the SnapClick target's `PBXSourcesBuildPhase`. Do not add either file to FinderExtension.

### Task 2: Dock Preview Latching and Stationary Geometry

- [ ] **Step 1: Extend the Dock contract test before production edits**

Add assertions to `scripts/test_dock_window_control.sh` for calls to `dockTargetCoreContains`, `dockRetentionContains`, a `dockLayoutAxis` mapping, and a same-app fast path that returns without calling `panel.setFrame` or rewriting the preview pointer frame.

- [ ] **Step 2: Run the Dock test and verify RED**

Run: `bash scripts/test_dock_window_control.sh`

Expected: failure on the first new latching assertion.

- [ ] **Step 3: Implement latched hover switching in `FinderDockPreviewController`**

Change `handleMouseMoved(axPoint:)` so that:

```swift
if let candidate = dockApp(atAXPoint: axPoint) {
    if let currentDockApp,
       currentDockApp.app.processIdentifier != candidate.app.processIdentifier,
       !dockTargetCoreContains(axPoint, bounds: candidate.bounds, axis: dockLayoutAxis()) {
        return
    }
    if currentDockApp?.app.processIdentifier != candidate.app.processIdentifier {
        currentDockApp = candidate
        showPreview(for: candidate)
        return
    }
    // Keep the originally latched bounds and use the existing refresh interval.
} else if let currentDockApp,
          dockRetentionContains(axPoint, bounds: currentDockApp.bounds, axis: dockLayoutAxis()) {
    return
}
```

Map bottom Dock to `.horizontal` and left/right Dock to `.vertical`. Keep click handling on direct `dockApp(atAXPoint:)` hit testing so clicks are not delayed by hover hysteresis.

- [ ] **Step 4: Freeze panel and pointer frames for the same latched app**

In `showPreview(for:)`, compute previews and their fingerprint before creating an `NSStackView`. If the panel is already visible for the same PID, fingerprint, and orientation, do not call `panel.setFrame` and do not rewrite the pointer view frame. Only keep the panel frontmost and load missing thumbnails. Build tile views and set geometry only for an initial display, an accepted app switch, or changed preview content.

- [ ] **Step 5: Run focused and existing tests**

Run:

```bash
bash scripts/test_window_interaction_geometry.sh
bash scripts/test_dock_window_control.sh
```

Expected: both pass.

### Task 3: Accurate, Passive Window Shake Controller

- [ ] **Step 1: Add failing integration contracts**

Extend `scripts/test_dock_window_control.sh` to require `WindowShakeController`, `.leftMouseDragged`, `options: .listenOnly`, `titleBarBounds`, `WindowShakeRecognizer`, `kAXMinimizedAttribute`, and restore entries keyed by `CGWindowID`. Require `AppDelegate` to start and stop the controller.

- [ ] **Step 2: Run the integration contract and verify RED**

Run: `bash scripts/test_dock_window_control.sh`

Expected: failure because `WindowShakeController.swift` and its AppDelegate wiring do not exist.

- [ ] **Step 3: Implement event handling without drag-path system queries**

Create `SnapClick/Core/WindowShakeController.swift`. Its event tap listens only for left down, left dragged, left up, and tap-disabled notifications. On down, record the point and timestamp. On the first drag beyond four points, perform one Accessibility hit test, walk parents to an `AXWindow`, confirm a standard window subrole, obtain its stable `CGWindowID`, and verify the pointer lies in `titleBarBounds(for:)` derived from the window frame plus its Accessibility title/minimize/zoom/close controls. Begin `WindowShakeRecognizer` from the down point. Every later drag calls only `recognizer.update`; mouse up clears the active gesture.

- [ ] **Step 4: Implement minimize snapshots and exact restore filtering**

On a recognized first shake, read `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` once. Keep layer-zero, normal Accessibility windows that are settable for `kAXMinimizedAttribute`, excluding the dragged ID and already minimized windows. Store:

```swift
private struct RestoreEntry {
    let windowID: CGWindowID
    let element: AXUIElement
    let frame: CGRect
    let frontToBackRank: Int
}

private struct RestoreSession {
    let keptWindowID: CGWindowID
    let keptWindow: AXUIElement
    let entries: [RestoreEntry]
}
```

Set `kAXMinimizedAttribute` to true only for stored entries. On the next recognized shake of the same kept window, verify each entry still resolves to the same ID, set minimized to false, restore a materially changed position/size, raise entries from back to front, and finally raise the kept window. Clear the session after restoration. A shake of a different window leaves the existing restore session untouched.

- [ ] **Step 5: Wire lifecycle and project membership**

Add `private let windowShakeController = WindowShakeController()` to `AppDelegate`, call `start()` from `applicationDidFinishLaunching`, and call `stop()` from `applicationWillTerminate`. Make the existing `_AXUIElementGetWindow` declaration internal so the controller can reuse it. Add `WindowShakeController.swift` to the SnapClick target.

- [ ] **Step 6: Run all contract tests and a Debug compile**

Run:

```bash
bash scripts/test_window_interaction_geometry.sh
bash scripts/test_dock_window_control.sh
bash scripts/test_hotkey_safety.sh
bash scripts/test_screenshot_annotation_contracts.sh
git diff --check
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Expected: all scripts pass, no whitespace errors, and Xcode reports `BUILD SUCCEEDED`.

### Task 4: Signed Release Artifact and Runtime Verification

- [ ] **Step 1: Build the signed Release app**

Run:

```bash
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData DEVELOPMENT_TEAM=HQ6YY6QF8H CODE_SIGN_IDENTITY="Apple Development: esc_g@hotmail.com (72LZ3ELC38)" CODE_SIGN_STYLE=Manual build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Package and verify the DMG**

Run:

```bash
scripts/build_dmg.sh build/DerivedData/Build/Products/Release/SnapClick.app
codesign --verify --deep --strict build/DerivedData/Build/Products/Release/SnapClick.app
hdiutil verify dist/SnapClick.dmg
shasum -a 256 dist/SnapClick.dmg
```

Expected: valid deep signature, `hdiutil` verification success, and a recorded SHA-256.

- [ ] **Step 3: Perform runtime checks where desktop interaction is available**

Verify bottom and side Dock target-core switching, stationary preview geometry under Dock magnification, normal Dock clicks, two-cycle title-bar shake, pre-minimized-window exclusion, same-window restore, closed-window skipping, current-Space isolation, and front-to-back restoration. Record any item that cannot be automated as unverified rather than inferring success from compilation.

- [ ] **Step 4: Commit the implementation after verification**

Run:

```bash
git add SnapClick/App/AppDelegate.swift SnapClick/Core/WindowInteractionGeometry.swift SnapClick/Core/WindowShakeController.swift SnapClick.xcodeproj/project.pbxproj scripts/test_window_interaction_geometry.swift scripts/test_window_interaction_geometry.sh scripts/test_dock_window_control.sh docs/superpowers/plans/2026-07-10-dock-preview-and-window-shake.md
git commit -m "feat: stabilize Dock previews and add window shake"
```
