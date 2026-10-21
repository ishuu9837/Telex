# Stealth verification — 21 October 2026

The local `sw_vers` command reports **macOS 27.0.1**, build **26A434**. The application uses `majorVersion >= 15`, so 15, 26, 27 and later versions display **Stealth: Limited** when enabled. The explanatory status says **macOS 15 or later**. No control promises invisibility.

## Completed checks

- Tests assert the Limited status for macOS 15, 16, 26, 27 and 99, and best-effort status on macOS 14.
- Native NSPanel test verifies activation sets `sharingType = .none` and deactivation restores `.readOnly`.
- These tests verify the requested OS flag and wording. They do **not** establish that third-party capture omits the window.
- Telex's built-in display recorder excludes its own application via ScreenCaptureKit independently of the Stealth toggle. End-to-end capture output still needs visual verification.

## External capture matrix

| Capture tool | Result in this session |
| --- | --- |
| Zoom | Not installed in `/Applications`; capture test not run. |
| Google Meet | No test meeting established; capture test not run. |
| Microsoft Teams | Not installed in `/Applications`; capture test not run. |
| QuickTime Player | System application opened. Automated Cancel, Escape, coordinate click and Raise did not dismiss its startup Open dialog. Recording workflow could not be reached; no capture result obtained. |
| OBS | Not installed in `/Applications`; capture test not run. |

**Do not treat this build as verified invisible in any of these tools.** Share a single application window or a second display instead of relying on whole-display exclusion.

## Reproducible manual check

1. Show a clearly identifiable Telex script on the test display and enable Stealth. Confirm that the app reports Limited.
2. Capture or share that entire display through the target tool, using a test recording or a separate viewer. Compare the actual output, not only the local preview.
3. Repeat with Stealth off as a control, then with single-application-window sharing. Verify the prompter stays visible to the presenter.
4. Repeat after dock/float, display change and full-screen transitions. Record the OS build, tool version, capture scope and whether Telex appears.
5. Check Telex's built-in recorder independently: its output should omit every Telex window with Stealth on and off.
