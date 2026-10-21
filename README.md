# Telex for macOS

A native, local teleprompter built with Swift 6, SwiftUI and AppKit. Requires macOS 14 or later. No external packages or network services.

## Open the app

The built application is `dist/Telex.app`. Open it in Finder, or open `dist/Telex.dmg` and drag Telex to Applications.

Create or import a script, use `# Heading` or `[Cue: Title]` to create sections, and choose **Start reading**. Voice-level pacing is the default and needs only microphone permission. **No microphone** mode scrolls continuously with no microphone, Siri or screen-recording access. Choose **Very slow (40), Slow (80), Medium (130), Medium fast (180), High (240), or Very high (300 WPM)**, or set a custom speed. Opt into **Follow: Script words** and choose an available on-device language for transcription that advances through matching words. Repeated words and off-script speech hold your place. Choose **Voice activity** for volume-based pacing, or turn **Follow my voice** off for constant speed. Speech Recognition permission is never requested automatically during playback. Only the explicit **Enable optional Apple transcription…** button can request it. You can leave it off and use voice-level pacing without Siri. The language list contains only on-device-capable languages and defaults to the system language when supported. If permission, language assets or recognition are unavailable, the app explains the fallback to voice-level pacing. Hover pauses temporarily, while the Pause button locks the pause. The inspector controls display, width, height, mirrors, text color and pace.

**Stealth Mode** can be switched on or off using the workspace toolbar, menu bar menu, or inspector. The choice is saved. macOS 15 and later can include a protected window in third-party captures; share a single app window or a second display. Built-in display recordings exclude the entire Telex application independently of this toggle.

Use **Record**, then explicitly click **Choose screen or window…** to request screen access and load capture sources. Merely opening the controls does not request access. Microphone and system-audio recording default off. Normal teleprompting and Stealth never require screen access.

## Build in Xcode

Open **`Telex.xcodeproj`** in Xcode, choose the **Telex** scheme and **My Mac**, then press **⌘R** to build and run the native app. Press **⌘U** to run the unit tests. This native app target includes the privacy usage descriptions, icon and entitlements. The Swift package remains available as an alternative command-line build.

## Local work proof

`BuildProof/README.md` links the native Xcode test result bundle, build/test logs, packaging log and implementation notes. All source files are under `Sources/Telex/`; tests are under `Tests/TelexTests/`. `Scripts/generate_xcode_project.py` regenerates the native Xcode project if files are added or removed.

The prompter has straight vertical sides, square top corners, rounded bottom corners, and no tapered edges or shadow in both modes. The reading text still respects the hardware notch's safe area.

## Build and package from Terminal

```sh
./Scripts/build_universal_dmg.sh
```

This runs the unit tests, builds both arm64 and x86_64, assembles the app with the supplied icon, verifies its signature and architectures, and creates `dist/Telex.dmg`. The default signature is ad hoc for local testing.

For Developer ID distribution, supply `SIGNING_IDENTITY` and an existing Keychain `NOTARY_PROFILE`:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-keychain-profile' ./Scripts/build_universal_dmg.sh
```

No signing credentials are stored in this repository. `SKIP_TESTS=1` skips tests for a packaging-only rerun.

## Intro, terms, and quick tour

On launch, a brief logo animation introduces Telex; Reduce Motion uses a static reveal and Skip intro is available. The versioned Terms of Service screen requires your own unchecked-by-default agreement before reading starts. Agreement does not grant any OS permissions. You can decline and quit, or review the terms from Help or Settings.

The five-step quick tour explains the editor, no-microphone speeds, voice pacing, controls and privacy. It has optional local chime sounds, a mute switch, Back/Next and Skip. Repeat it from Help, Settings or the menu bar. The tour never turns on the microphone or records your screen.

## Prompter controls and scrolling

The prompter controls accept the first click while another app has focus. Hover reveals Play/Pause, cues, speed/mode, dock/float, more actions, and **Quit Telex**. The more menu includes restart/stop/hide, recording controls, and the workspace. A separate drag handle moves the floating window; it does not intercept button clicks.

Hover intentionally pauses scrolling: move the pointer away to resume, or click Pause to lock it. The playback clock stays active through silence, so speaking can resume scrolling. If your voice is too quiet for the sensitivity setting, speak and use **Adjust sensitivity from my voice**, or switch to No microphone. Empty scripts show an instruction instead of starting an idle microphone session.

## Microphone and editing

The microphone is off while editing. Reading starts it only after the countdown, and manual/hover pause, hiding the prompter, stopping or focusing the script editor releases it. **Test microphone** explicitly enables the labelled **Input level** meter; scrolling it out of view, leaving the inspector, deactivating the app or stopping the test releases the microphone. An explicitly started screen recording with microphone audio is a separate, user-controlled audio session.

The workspace moves below the capsule when possible, and returning to the editor hides the capsule. Click-through displays an always-visible warning and can be disabled in the toolbar, menu bar, inspector or with ⇧⌘L.

Stealth remains best effort. See `STEALTH_VERIFICATION.md` for the actual OS and capture-tool test matrix.

## Data and recovery

Scripts are stored as versioned ISO-8601 JSON in `~/Library/Application Support/Telex/Scripts/`. Writes flush a temporary file before atomic replacement. Unreadable files are preserved and can be revealed in Finder. Edits save after 500 ms; pending drafts flush before quitting. Preferences use UserDefaults. Recordings go to the location you select.

See `BuildProof/FEATURE_VERIFICATION.md` and `BUILD_NOTES.md` for validation and limitations. The original product brief, architecture, and visual references remain in the repository.

## Open source and development release

Telex source is available under the [MIT license](LICENSE). Download builds from [GitHub Releases](https://github.com/ishuu9837/Telex/releases). See [release notes](RELEASE_NOTES.md) for verification scope and known limitations. The current development build is not notarized.
