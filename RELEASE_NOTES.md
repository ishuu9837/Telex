# Telex v1.0.0-dev.1

First development prerelease for macOS 14 or later, with Apple silicon and Intel binaries.

- Local script editor, imports/exports, autosave and navigable cues.
- Camera-adjacent floating prompter, adjustable type, colours, size and mirroring.
- Continuous no-microphone scrolling, voice-level pacing and optional on-device word following.
- Blue bubble glow, intro, consent page and optional quick tour.
- Optional ScreenCaptureKit screen recording with an own-app exclusion filter.

## Verification

54 unit/integration tests passed in native Xcode and Swift package runs. Xcode analysis passed. The latest test run did not reproduce the fixed geometry-cycling warning. Fifteen scoped static privacy/configuration checks passed. These results are not full hardware or security certification.

## Development-build limitations

The application is ad-hoc signed and **not Developer ID signed or notarized**. Gatekeeper assessment has not passed; macOS may block opening it. This is a prerelease, not a production-ready distribution.

Live microphone meter movement has been confirmed. Script-word accuracy, Zoom/Meet/Teams/OBS capture behavior, recording interruption recovery, full accessibility and sustained performance validation remain incomplete. Separate Manual mode and built-in camera recording are not implemented.

Stealth is best effort and Limited on macOS 15 or later. Other applications may capture the prompter in full-display sharing. macOS privacy indicators cannot be hidden.

## Download verification

Download `Telex.dmg` and `SHA256SUMS.txt` from this release. In their folder, run `shasum -a 256 -c SHA256SUMS.txt`. Source archives are provided automatically by GitHub. The source is MIT licensed; Apple trademarks remain their owners' property.
