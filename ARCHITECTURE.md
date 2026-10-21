# Telex (macOS) — Unified Software Architecture (ARCHITECTURE.md)

**Product Name:** Telex  
**Status:** **APPROVED FOR IMPLEMENTATION (MAC ONLY)**  
**Target Platform:** Native macOS Universal Binary (`arm64` Apple Silicon + `x86_64` Intel), `macOS 14.0+` & `macOS 15.0+`  
**Source of Truth:** `PRD.md`, `DESIGN.md`, `DATABASE.md`, `API.md`  

## 1. Architectural Principles & Approved Tech Stack

Telex is a **100% local, native macOS application** built with **Swift 6, SwiftUI, and AppKit** with zero external cloud services, zero user accounts, and zero third-party package dependencies required.

| Layer / Capability | Approved Technology | Architectural Reasoning |
| :--- | :--- | :--- |
| **Language & Concurrency** | **Swift 6.0** (`@MainActor` UI + Swift Actors) | Strict concurrency safety across real-time audio taps, screen recording queues, and 120Hz UI rendering. |
| **Prompter Window** | **AppKit `NSPanel`** + **SwiftUI `NSHostingView`** | Non-activating floating panel (`.nonactivatingPanel`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`) floats over full-screen presentations without stealing focus from Zoom, Keynote, or browsers. |
| **Camera & Notch Placement** | **`NSScreen` Geometry (`DisplayGeometryService`)** | Uses `safeAreaInsets.top`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` to dock seamlessly into the MacBook notch, or top-center bezel on iMacs and external monitors. |
| **Voice Pacing & Visual Beam** | **`AVAudioEngine` (Fast VAD) + `SFSpeechRecognizer` (On-Device Word Sync)** | Default RMS Voice-Activity Detector with hysteresis + sensitivity slider provides zero-setup, language-independent `<100ms` pause/resume and drives the **Voice Visual Feedback Beam**; optional on-device `SFSpeechRecognizer` provides word-level tracking. |
| **Screen Recording** | **`ScreenCaptureKit` (`SCStream`) + `AVAssetWriter`** | Hardware-accelerated H.264/HEVC `.mp4`/`.mov` capture (`SCRecordingOutput` supported on macOS 15+). Always excludes Telex's own windows via `SCContentFilter`. |
| **Stealth Mode** | **`NSWindow.sharingType = .none` (`CaptureExclusionService`)** | Excludes the prompter from legacy capture & screenshots, excludes Telex from its own recordings, and surfaces accurate OS status (`Active` / `Limited on macOS 15+`). |
| **Global Shortcuts** | **Carbon `RegisterEventHotKey` (`GlobalHotkeyService`)** | Works while other apps (Zoom, PowerPoint, VS Code) hold focus without requiring intrusive macOS Accessibility (keylogger) TCC permissions. |
| **Local Persistence** | **Atomic Versioned JSON (`ScriptRepository`) + `UserDefaults` (`PreferencesStore`)** | Stores one atomic JSON document per script in `~/Library/Application Support/Telex/Scripts/` and typed preferences in `UserDefaults`—zero SQLite migration fragility, 100% crash-safe atomic replacement, and instant unit testability. |

## 2. Modular System Architecture & Data Flow

```
+---------------------------------------------------------------------------------------+
|                          PRESENTATION LAYER (@MainActor)                              |
|  +-------------------------+  +-------------------------+  +-----------------------+  |
|  | TeleprompterPanel       |  | WorkspaceWindow         |  | MenuBarExtra,         |  |
|  | - NotchExtensionShape   |  | - Script Library & Cues |  | OnboardingWindow &    |  |
|  | - VoiceBeamVisualView   |  | - Built-in Cue Editor   |  | SettingsWindow        |  |
|  | - HoverPauseOverlay     |  | - Live Stretch/Color UI |  | - Stealth/Mic/Hotkeys |  |
|  +------------+------------+  +------------+------------+  +-----------+-----------+  |
|               |                            |                           |              |
|               +----------------------------+---------------------------+              |
|                                            |                                          |
|                                            v                                          |
|                      +------------------------------------------+                     |
|                      |       AppCoordinator & ViewModels        |                     |
|                      |  (@Observable: PrompterViewModel,        |                     |
|                      |   ScriptEditorViewModel, RecordingVM)    |                     |
|                      +---------------------+--------------------+                     |
+--------------------------------------------|------------------------------------------+
                                             | Protocol Interfaces (API.md)
+--------------------------------------------v------------------------------------------+
|                        DOMAIN SERVICES & MACOS OS ADAPTERS                            |
|  +-------------------------+  +-------------------------+  +-----------------------+  |
|  | VoicePacingService      |  | PrompterWindowService   |  | ScreenRecorderService |  |
|  | - AVAudioEngine VAD     |  | - NSPanel Non-Activating|  | - ScreenCaptureKit    |  |
|  | - SFSpeech On-Device    |  | - Hover-to-Pause Tracker|  | - SCContentFilter     |  |
|  | - Voice Beam dB Stream  |  | - Stretch & Mirror Flip |  | - AVAssetWriter (MP4) |  |
|  +-------------------------+  +-------------------------+  +-----------------------+  |
|  +-------------------------+  +-------------------------+  +-----------------------+  |
|  | TelexCueService         |  | CaptureExclusionService |  | ScriptRepository &    |  |
|  | - Cue Parser & Indexer  |  | - sharingType = .none   |  | PreferencesStore      |  |
|  | - Instant Section Jump  |  | - OS Status Reporting   |  | - Atomic JSON Writes  |  |
|  | - Return-to-Spot Stack  |  | - Self-Capture Exclude  |  | - UserDefaults Store  |  |
|  +-------------------------+  +-------------------------+  +-----------------------+  |
+---------------------------------------------------------------------------------------+
```

## 3. Core Subsystem Specifications

### 3.1 `PrompterWindowService` & Hover-to-Pause State Machine
- **Window Configuration:** `TeleprompterPanel` subclasses `NSPanel` with `[.borderless, .nonactivatingPanel]`, `level = .statusBar + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `isOpaque = false`, `backgroundColor = .clear`.
- **Hover-to-Pause vs. Click-to-Lock-Pause State Machine:**
  - Uses `NSTrackingArea` (`.mouseEnteredAndExited`, `.activeAlways`) on the panel's content view:
    - `mouseEntered`: If `scrollState == .scrolling`, transitions immediately (`< 16 ms`) to `.hoverPaused` and fades in `HoverPauseOverlay`.
    - `mouseExited`: If `scrollState == .hoverPaused` (user did not click the Lock Pause button), transitions back to `.scrolling` automatically!
    - Clicking the Pause button inside `HoverPauseOverlay` (or pressing `Cmd+Return`) sets `scrollState = .manualPaused`, which stays paused even after the cursor leaves until clicked again or resumed via hotkey.
- **Two-Finger Trackpad Manual Scroll:** Overrides `scrollWheel(with event: NSEvent)` on `TeleprompterPanel` so two-finger vertical scrolling adjusts `scrollOffsetY` smoothly at any time without activating the window.

### 3.2 `VoicePacingService` & Voice Visual Feedback Beam
- **Audio Tap & Voice Band Filter:** Installs a `1024`-frame tap on `AVAudioEngine.inputNode`, applies a lightweight biquad bandpass filter (`85 Hz – 3400 Hz` human speech band to reject low-frequency HVAC rumble and high-frequency mouse clicks), and computes RMS power in dBFS using `Accelerate` (`vDSP_rmsqv`).
- **Hysteresis State Machine (`Idle -> Listening -> Speaking -> SilenceHold -> Paused`):**
  - Compares filtered dBFS against user-configurable `sensitivityThresholdDB` (default `-38 dBFS`).
  - When `level >= sensitivityThresholdDB`: state becomes `.speaking`, advancing scroll offset smoothly and driving the **Voice Visual Feedback Beam** normalized intensity (`0.0 ... 1.0`).
  - When `level < sensitivityThresholdDB - 4 dB` (4 dB hysteresis): enters `.silenceHold` for `silenceHoldDurationMs` (default `350 ms`, configurable `150–800 ms`) before pausing scroll, preventing micro-stutters between syllables while stopping promptly when the speaker pauses.
- **Optional Word-Level Follow-Along:** When enabled in Settings, feeds the same audio buffer into `SFSpeechAudioBufferRecognitionRequest` (`requiresOnDeviceRecognition = true`) and aligns spoken words via `TokenAlignmentAlgorithm`.

### 3.3 `TelexCueService` (Script Sections & Out-of-Order Jumping)
- Parses script text for lines starting with `# `, `## `, `### `, or `[Cue: ...]` and builds an ordered array of `ScriptCue(id, title, characterOffset, lineIndex, targetScrollOffsetY)`.
- Maintains `returnPositionStack: [CGFloat]`. When the user jumps to a Cue during a presentation (`jumpToCue(id)`), pushes the current `scrollOffsetY` onto `returnPositionStack` so clicking **"Resume Where I Left Off"** (`popReturnPosition()`) restores the exact prior reading spot.

## 4. Complete Repository Folder Structure

```
Telex/
├── Package.swift                               # Swift 6 Package manifest (builds via swift build / Xcode)
├── Config/
│   ├── Info.plist
│   └── Telex.entitlements
├── Assets/
│   ├── AppIcon.icns                          # Final app icon (from the supplied logo)
│   ├── AppIcon-1024.png
│   ├── AppIcon.iconset/                      # All macOS icon sizes
│   └── logo-source.png                       # Original supplied logo (1920x1920)
├── Scripts/
│   ├── make_icns.sh                          # Rebuilds AppIcon.icns with Apple's iconutil
│   └── build_universal_dmg.sh                # Phase 8: build, assemble .app, sign, notarize, package
├── Sources/
│   └── Telex/
│       ├── App/
│       │   ├── TelexApp.swift                  # @main entry point (WindowGroup, MenuBarExtra, Settings)
│       │   ├── AppDelegate.swift               # NSPanel lifecycle, URL scheme, screen change observer
│       │   └── AppCoordinator.swift            # Central dependency injection & state coordinator
│       ├── Models/
│       │   ├── ScriptDocument.swift            # Codable versioned Script model + ScriptCue
│       │   ├── AppPreferences.swift            # Codable validated Preferences + PerDisplayGeometry
│       │   └── PacingAndCaptureState.swift     # Explicit enums for Voice, Scroll, Stealth & Recording
│       ├── Services/
│       │   ├── ScriptRepository.swift          # Atomic JSON persistence in Application Support/Telex/Scripts
│       │   ├── PreferencesStore.swift          # Typed UserDefaults persistence with range validation
│       │   ├── DisplayGeometryService.swift    # Notch detection (safeAreaInsets/auxiliaryTopArea) & iMac/Monitor math
│       │   ├── PrompterWindowService.swift     # Non-activating NSPanel, Hover-to-Pause, Trackpad scroll, Stretch
│       │   ├── VoicePacingService.swift        # AVAudioEngine VAD + hysteresis + On-device Speech + Voice Beam dB
│       │   ├── TelexCueService.swift           # Cue parsing, instant section jump, return-to-spot bookmark stack
│       │   ├── CaptureExclusionService.swift   # Stealth Mode (sharingType = .none) + OS status detection
│       │   ├── ScreenRecorderService.swift     # ScreenCaptureKit + AVAssetWriter (excludes Telex windows)
│       │   ├── GlobalHotkeyService.swift       # Carbon RegisterEventHotKey wrapper
│       │   └── PermissionService.swift         # Microphone, Speech & Screen Recording TCC status/prompts
│       ├── Features/
│       │   ├── Prompter/
│       │   │   ├── PrompterViewModel.swift
│       │   │   ├── PrompterCapsuleView.swift   # NotchExtensionShape + VoiceBeamVisualView + Centered scroll
│       │   │   ├── HoverPauseOverlayView.swift # Compact hover controls + Cue jump bar
│       │   │   └── CountdownOverlayView.swift  # 3-2-1 preparation timer
│       │   ├── Workspace/
│       │   │   ├── WorkspaceView.swift         # Library sidebar + Built-in Cue Editor + Live Inspector
│       │   │   ├── ScriptEditorView.swift      # Editor with Cmd+K Split into Cue & read-time estimator
│       │   │   └── PrompterInspectorView.swift # Stretch size, Text color picker, Speed, Mic sensitivity
│       │   ├── Onboarding/
│       │   │   └── OnboardingView.swift        # 3-step setup on periwinkle-ultramarine reference backdrop
│       │   ├── MenuBar/
│       │   │   └── MenuBarView.swift
│       │   └── Settings/
│       │       └── SettingsView.swift
│       └── Shared/
│           ├── DesignTokens.swift              # Colors, Fonts, Presets from DESIGN.md
│           └── AppLogger.swift                 # Privacy-safe os.Logger wrapper
└── Tests/
    └── TelexTests/
        ├── ScriptRepositoryTests.swift
        ├── VoicePacingStateMachineTests.swift
        ├── TelexCueServiceTests.swift
        ├── DisplayGeometryServiceTests.swift
        └── PreferencesStoreTests.swift
```

## 5. Security, Privacy, and Entitlements

- **Least-Privilege Entitlements (`Config/Telex.entitlements`):**
  - `com.apple.security.device.audio-input = true` (Microphone for voice pacing & voiceover recording)
  - `com.apple.security.personal-information.speech-recognition = true` (Optional on-device word tracking)
  - `com.apple.security.files.user-selected.read-write = true` (Importing scripts & saving recordings)
  - No network entitlements. Telex opens no listening sockets and makes no outbound connections.
- **Zero Data Exfiltration:** Never log script contents, audio buffers, or personal file paths.

## 6. Packaging, App Icon and Distribution

- `swift build` produces a bare executable, not a signed `.app`. `Scripts/build_universal_dmg.sh` must: build `arm64` and `x86_64` (`swift build -c release --arch arm64 --arch x86_64`), assemble `Telex.app` (`Contents/MacOS/Telex`, `Contents/Info.plist` from `Config/`, `Contents/Resources/AppIcon.icns` from `Assets/`), sign with the Hardened Runtime and `Config/Telex.entitlements`, create `Telex.dmg`, then notarize and staple (`notarytool`). The script reads the signing identity and notary profile from environment variables and never hard-codes them.
- The app icon is the supplied logo (black M with blue X on a white rounded square), already processed into a transparent 1024 px macOS icon plus a full `.iconset`. `Info.plist` references it through `CFBundleIconFile = AppIcon`.
- Distribution: direct download (Developer ID + notarization) is the primary path. Mac App Store readiness (Task 26) requires the App Sandbox and a separate entitlement review and is optional.
