# External Display Software Volume Design

Date: 2026-07-11

## Goal

Add one system-volume slider to the SnapClick status menu that can attenuate
audio sent to fixed-volume HDMI, DisplayPort, and USB output devices. The
feature must not depend on DDC/CI or on another installed audio application.

## Supported Systems

- SnapClick keeps its current macOS 13 minimum deployment target.
- Prefer an AudioDriverKit system extension when the signing team has the
  required audio DriverKit entitlement.
- If that entitlement cannot be used for local and CI distribution, use a
  SnapClick-owned HAL AudioServerPlugIn installed with administrator approval.
- Both backends expose the same app-side interface and menu behavior.

## User Experience

- Insert one separator and one horizontal volume row between the recording
  commands and the color/pin commands in the status menu.
- The row contains a speaker icon, one slider, and a percentage value.
- If the audio component is unavailable, replace the slider with an `Enable
  Volume Control` action that starts the system-approved installation flow.
- Enabling the feature may require administrator or system-extension approval.
- The menu must remain usable while installation or audio recovery is pending.

## Audio Architecture

The SnapClick virtual device becomes the default system output. Its stereo PCM
stream is forwarded in real time to the physical output device that was active
before activation. A scalar gain from 0.0 through 1.0 is applied before writing
to the physical device. The first version supports only stereo PCM and system
master attenuation; it does not implement per-application routing, boost,
equalization, or device selection.

The app-side controller owns:

- component installation and state reporting;
- capture of the previous physical default output;
- default-output switching;
- the real-time forwarding engine and gain value;
- output-device change and reconnect handling;
- restoration during disable, termination, or failed startup.

The real-time callback performs no allocation, locking, logging, UI work, or
file access. The menu observes controller state on the main actor.

## Failure And Recovery

- Never select the SnapClick virtual device until forwarding to a physical
  output is ready.
- Never choose the SnapClick virtual device as its own physical destination.
- If the physical output disappears, pause forwarding and select the current
  non-SnapClick default output when one becomes available.
- If startup fails after changing the default device, restore the saved output.
- On normal app termination or explicit disable, restore the saved output.
- Preserve the last slider value in `AppSettings`; do not persist transient
  device identifiers as permanent user preferences.
- A crash cannot guarantee app-level cleanup, so the next launch detects a
  virtual default device without a running forwarding engine and repairs it
  before enabling audio control.

## Installation And Distribution

- The audio component uses SnapClick-owned identifiers and Apache-2.0-compatible
  source; no GPL driver binary or source is bundled.
- The app, Finder extension, and audio component must be signed by team
  `HQ6YY6QF8H` for installable builds.
- DriverKit activation uses the system extension APIs. The HAL fallback uses a
  narrowly scoped privileged installer to place the signed bundle under
  `/Library/Audio/Plug-Ins/HAL` and restart Core Audio.
- The signed Release DMG build and GitHub Actions workflow must verify the audio
  component identity in addition to existing app and Finder-extension checks.

## Verification

- Unit-test gain clamping, state transitions, destination filtering, and
  restoration decisions before production implementation.
- Run the existing focused scripts and a Debug compile check.
- Build the signed Release app and DMG, verify every bundled code signature,
  run `hdiutil verify`, and record the SHA-256.
- Manually verify with a fixed-volume HDMI/DisplayPort output: continuous audio,
  slider response from 0-100%, mute behavior, unplug/replug, output switching,
  app quit/relaunch recovery, and absence of feedback loops.

## Explicit Non-Goals

- DDC/CI display control
- output boost above 100%
- per-application volume
- input-volume control
- effects, equalization, or device selection UI
- reuse of an installed Background Music, BlackHole, SoundSource, or eqMac driver
