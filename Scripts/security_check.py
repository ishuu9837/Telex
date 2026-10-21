#!/usr/bin/env python3
"""Static privacy-policy checks. Not a penetration test or capture-compatibility certification."""
from pathlib import Path
import plistlib, re, sys
root = Path(__file__).resolve().parent.parent
sources = {str(p.relative_to(root)): p.read_text() for p in (root/'Sources'/'Telex').rglob('*.swift')}
checks = []
def check(name, passed, detail=''):
    checks.append(passed)
    print(('PASS' if passed else 'FAIL') + ': ' + name + (' — ' + detail if detail else ''))
combined='\n'.join(sources.values())
network=re.findall(r'\b(?:URLSession|NWConnection|NWListener|WKWebView|XMLHttpRequest)\b', combined)
check('No application networking clients or embedded web content', not network)
entitlements=plistlib.loads((root/'Config'/'Telex.entitlements').read_bytes())
check('No network entitlements', not any('network' in key for key in entitlements))
check('No debug or library-validation bypass entitlements', not any(key in entitlements for key in ['com.apple.security.get-task-allow','com.apple.security.cs.disable-library-validation','com.apple.security.cs.allow-unsigned-executable-memory']))
info=plistlib.loads((root/'Config'/'Info.plist').read_bytes())
check('Microphone and speech permission purpose strings present', bool(info.get('NSMicrophoneUsageDescription')) and bool(info.get('NSSpeechRecognitionUsageDescription')))
check('No forced try/casts in production source', not re.search(r'\b(?:try|as)!',combined))
voice=sources['Sources/Telex/Services/VoicePacingService.swift']
check('Apple transcription explicitly restricted to on-device', 'request.requiresOnDeviceRecognition = true' in voice)
coordinator=sources['Sources/Telex/App/AppCoordinator.swift']
check('Speech permission request exists only in explicit opt-in method', coordinator.count('permissions.requestSpeechRecognition()') == 1 and 'func enableOptionalTranscription()' in coordinator)
recording_view=sources['Sources/Telex/Features/Workspace/RecordingControlsView.swift']
check('Opening recorder sheet does not trigger a task requesting capture', '.task {' not in recording_view)
recorder=sources['Sources/Telex/Services/ScreenRecorderService.swift']
check('Shareable-content enumeration guarded by existing permission', 'guard CGPreflightScreenCaptureAccess()' in recorder)
check('Display recordings exclude this application', 'excludingApplications: Self.excludedApplications(content.applications)' in recorder and '$0.processID == ProcessInfo.processInfo.processIdentifier' in recorder)
check('Cannot select Telex as a single-window capture target', 'Telex windows cannot be recorded.' in recorder)
status=sources['Sources/Telex/Services/CaptureExclusionService.swift']
check('Stealth remains Limited on macOS 15 or later', 'majorVersion >= 15' in status and '15 or later' in status and 'Limited' in status)
check('System microphone-indicator limitation is explicit', 'does not hide macOS microphone' in status)
check('Terms acceptance does not grant OS permissions', 'Agreeing to these terms does not grant microphone' in combined)
check('Prompting audio demand includes a no-microphone branch', 'voiceEnabled: preferences.voicePacingEnabled' in coordinator and 'case noMicrophone' in combined)
print(f'\n{sum(checks)}/{len(checks)} static checks passed.')
print('Scope: source/configuration policy checks only. Live microphone, capture-tool, accessibility, performance and adversarial testing are separate checks.')
sys.exit(0 if all(checks) else 1)
