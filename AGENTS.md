# SnapClick Project Notes

## Scope
- macOS app built with AppKit, SwiftUI, ScreenCaptureKit, and CoreAudio.
- Keep screenshot, recording, pin/color, right-click, and status-bar behavior separated by module.
- Prefer small AppKit-native changes over new dependencies.

## Build And Verification
- Before any push for code changes, build and verify a local DMG first. Follow this order:
  1. Debug compile check.
  2. Release compile with `CODE_SIGNING_ALLOWED=NO` and `-derivedDataPath build/DerivedData`.
  3. Build `dist/SnapClick.dmg` from the Release app using `scripts/build_dmg.sh`.
  4. Verify the DMG with `hdiutil verify`.
  5. Record the DMG SHA-256 with `shasum -a 256`.
  6. Only then commit, push, and watch GitHub Actions.
- Debug compile check:
  `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- CI-equivalent Release build:
  `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- DMG packaging:
  `scripts/build_dmg.sh build/DerivedData/Build/Products/Release/SnapClick.app`
- DMG verification:
  `hdiutil verify dist/SnapClick.dmg`
- DMG checksum:
  `shasum -a 256 dist/SnapClick.dmg`
- Normal signed local builds need the configured Mac Development certificate. Use `CODE_SIGNING_ALLOWED=NO` for compile-only verification.

## Screenshot Contracts
- Area selection keeps the previous dimmed overlay outside the selected region.
- Reduced contrast is only for highlight-tool rendering inside the annotation canvas.
- Screenshot output effects, including rounded corners and shadow, must go through `ScreenCaptureEngine.applyScreenshotEffects(to:)` so copy/save/export stay consistent.
- In-place and standalone annotation toolbars should stay behaviorally aligned.
- Each active annotation tool expands into its own size capsule; do not reintroduce a shared right-side size slider.
- The common color presets must include white and black.

## Dock Volume Contract
- Dock scroll volume control is based on the Dock region, not individual Dock icons.
- Volume changes use CoreAudio default output volume, not AppleScript or simulated media keys.
- Input Monitoring and Accessibility permission paths must keep retry behavior after permission grant.

## Push Checklist
- Do not push code changes until the local Release DMG has been built and verified.
- Push to `origin/main` unless a task explicitly asks for another branch.
- After pushing, check the GitHub Actions `Build` workflow result before calling the task done.
