# SnapClick Project Notes

## Scope
- macOS app built with AppKit, SwiftUI, ScreenCaptureKit, and CoreAudio.
- Keep screenshot, recording, pin/color, right-click, and status-bar behavior separated by module.
- Prefer small AppKit-native changes over new dependencies.

## Build And Verification
- Before any push for code changes, build and verify a local DMG first. Follow this order:
  1. Debug compile check can use `CODE_SIGNING_ALLOWED=NO`.
  2. For any DMG that will be installed or used to test permissions, build a signed Release app. Do not use `CODE_SIGNING_ALLOWED=NO` for that DMG.
  3. If the project team has no local certificate, override with the installed Apple Development certificate's OU team id. On this machine the working values are `DEVELOPMENT_TEAM=HQ6YY6QF8H` and `CODE_SIGN_IDENTITY="Apple Development: esc_g@hotmail.com (72LZ3ELC38)"`.
  4. Build `dist/SnapClick.dmg` from the signed Release app using `scripts/build_dmg.sh`.
  5. Verify app signing with `codesign --verify --deep --strict`.
  6. Verify the DMG with `hdiutil verify`.
  7. Record the DMG SHA-256 with `shasum -a 256`.
  8. Only then commit, push, and watch GitHub Actions.
- Debug compile check:
  `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- Signed local Release build for installable/auth-test DMG:
  `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData DEVELOPMENT_TEAM=HQ6YY6QF8H CODE_SIGN_IDENTITY="Apple Development: esc_g@hotmail.com (72LZ3ELC38)" CODE_SIGN_STYLE=Manual build`
- CI-equivalent unsigned Release build, only for CI parity and compile checks:
  `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- DMG packaging:
  `scripts/build_dmg.sh build/DerivedData/Build/Products/Release/SnapClick.app`
- App signing verification:
  `codesign --verify --deep --strict build/DerivedData/Build/Products/Release/SnapClick.app`
- DMG verification:
  `hdiutil verify dist/SnapClick.dmg`
- DMG checksum:
  `shasum -a 256 dist/SnapClick.dmg`
- Unsigned or ad-hoc builds are not valid for testing Accessibility/Input Monitoring authorization because TCC permissions are tied to the app identity. Use `CODE_SIGNING_ALLOWED=NO` only for compile-only verification.

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
- Do not push code changes until a signed local Release DMG has been built, code-sign verified, and DMG verified.
- Push to `origin/main` unless a task explicitly asks for another branch.
- After pushing, check the GitHub Actions `Build` workflow result before calling the task done.
