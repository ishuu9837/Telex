#!/usr/bin/env python3
"""Regenerate Telex's 14 self-contained README SVGs using only Python's stdlib."""
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets' / 'readme'
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
DEFS = '''<defs>
<linearGradient id="bg" x2="1" y2="1"><stop stop-color="#090D16"/><stop offset="1" stop-color="#101B30"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#0066FF" stop-opacity=".32"/><stop offset="1" stop-color="#0066FF" stop-opacity="0"/></radialGradient>
<pattern id="grid" width="28" height="28" patternUnits="userSpaceOnUse"><circle cx="14" cy="14" r="1" fill="#60A5FA" opacity=".1"/></pattern>
</defs>'''

def text(x, y, value, size=16, color='#F8FAFC', weight=400, extra=''):
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" {extra}>{escape(value)}</text>'

def write(name, height, body, description):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="{height}" viewBox="0 0 1000 {height}" role="img" aria-labelledby="title desc">
<title id="title">{escape(description)}</title><desc id="desc">Telex for macOS. Electric cobalt, deep carbon and studio white.</desc>
{DEFS}
<rect width="1000" height="{height}" rx="18" fill="url(#bg)"/>
<ellipse cx="160" cy="20" rx="450" ry="240" fill="url(#glow)"/>
<rect width="1000" height="{height}" rx="18" fill="url(#grid)"/>
<rect x="1" y="1" width="998" height="{height-2}" rx="17" fill="none" stroke="#315080" stroke-opacity=".6"/>
<g font-family="{FONT}">{body}</g></svg>\n'''
    (OUT / name).write_text(svg, encoding='utf-8')

SECTIONS = [
('overview', 'PACING & READING', 'Your words. Your pace.',
 [('01 / NO MICROPHONE', 'Read with no permissions', ['Continuous scrolling. Six speed presets.', '40 / 80 / 130 / 180 / 240 / 300 WPM.', 'Choose a custom pace; pause or resume.']),
  ('02 / VOICE LEVEL', 'Move while you speak', ['Default pacing uses microphone input only.', 'Adjust sensitivity with the live input meter.', 'No Speech or Siri authorization required.']),
  ('03 / SCRIPT WORDS', 'Follow your place', ['Optional Apple on-device transcription.', 'Explicit permission and supported language.', 'Unavailable? Fall back to voice-level pacing.'])]),
('stealth', 'PLACEMENT & CAPTURE', 'Close to your camera. Clear about privacy.',
 [('CAMERA-ADJACENT', 'A panel that fits your Mac', ['Dock near the notch or float on a display.', 'Straight sides and rounded bottom corners.', 'Resize, mirror, recolour and adjust opacity.']),
  ('STEALTH / BEST EFFORT', 'Limited on macOS 15+', ['Other apps may capture the floating panel.', 'Share an app window, use a second display,', 'or hide Telex with its keyboard shortcut.']),
  ('OPTIONAL SCREEN RECORDING', 'You choose when to capture', ['Screen access is requested explicitly.', 'Own-app exclusion filter is configured.', 'Recorded-output exclusion still needs QA.'])]),
('controls', 'PROMPTER CONTROLS', 'Stay in the moment. Keep control.',
 [('HOVER & PAUSE', 'A pause when you need it', ['Hover to pause; leave to resume.', 'Click Pause to hold your place.', 'Scroll manually and jump between cues.']),
  ('KEYBOARD RECOVERY', 'Always a way back', ['Shift + Command + T: show or hide.', 'Shift + Command + L: click-through toggle.', 'Quit and workspace actions in the controls.']),
  ('MICROPHONE LIFECYCLE', 'Honest microphone status', ['Reading or an explicit mic test uses input.', 'Pause, stop or edit to release pacing input.', 'Recording audio is separately controlled.'])]),
('tour', 'ONBOARDING & STORAGE', 'A calm start. Your scripts stay local.',
 [('FIRST LAUNCH', 'An introduction at your pace', ['Logo reveal respects Reduce Motion.', 'Versioned terms require your agreement.', 'Accepting terms grants no OS permissions.']),
  ('QUICK TOUR', 'Five steps to get going', ['Learn the editor, pacing and controls.', 'Optional local chimes, mute and skip.', 'The tour requests no capture permissions.']),
  ('LOCAL FILES', 'Save, recover, continue', ['Atomic JSON saves and draft autosave.', 'Unreadable files are preserved for recovery.', 'Cue markers: # Heading or [Cue: Title].'])]),
('build', 'BUILD & PACKAGE', 'Native Swift. Ready for your Xcode.',
 [('MACOS 14+', 'Apple silicon + Intel', ['Swift 6, SwiftUI and AppKit.', 'Apple frameworks; no external packages.', 'Native NSPanel hosts the prompter.']),
  ('XCODE WORKFLOW', 'Run and inspect the source', ['Open Telex.xcodeproj; choose Telex.', 'Command + R runs; Command + U tests.', 'Sources/Telex and Tests/TelexTests.']),
  ('UNIVERSAL PACKAGING', 'Build your own DMG', ['Scripts/build_universal_dmg.sh', 'Runs tests and builds both architectures.', 'Ad-hoc signing is the local default.'])]),
('release', 'VERIFICATION & RELEASE', 'Working code. Visible limits.',
 [('RECORDED VERIFICATION', '54 tests passed', ['Native Xcode and Swift package runs.', 'Xcode analysis and scoped static checks.', 'These are not security certification.']),
  ('DEVELOPMENT PRERELEASE', 'Not notarized yet', ['v1.0.0-dev.1 is ad-hoc signed.', 'Gatekeeper may block opening the app.', 'Developer ID distribution is pending.']),
  ('QA STILL REQUIRED', 'Test the real workflows', ['Speech accuracy and capture-tool matrix.', 'Recording interruption recovery.', 'Full accessibility and performance review.'])]),
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Vector reproduction of the product's M/X mark; no remote image dependencies.
    icon = '''<g transform="translate(58 55)"><rect width="170" height="170" rx="38" fill="#fff"/>
<circle cx="85" cy="36" r="11" fill="#090D16"/>
<path d="M32 138V54L48 44 81 71V96L51 72V124Z M138 138V54L122 44 89 71V96L119 72V124Z" fill="#090D16"/>
<path d="M54 78 85 103 116 78V97L97 112 128 138H104L85 122 66 138H42L73 112 54 97Z" fill="#0066FF"/></g>'''
    hero = icon + text(272, 68, 'NATIVE MACOS TELEPROMPTER', 12, '#60A5FA', 700, 'letter-spacing="2"')
    hero += text(268, 130, 'Telex for macOS', 55, weight=800)
    hero += text(272, 171, 'Keep your eyes up. Find your flow.', 25, '#D7E5FF', 500)
    hero += text(272, 210, 'Local scripts. Camera-adjacent reading. Your choice of pace.', 17, '#A5B4CC')
    for x, label in [(272, 'macOS 14+'), (442, 'Swift 6'), (612, 'Universal'), (782, 'MIT licensed')]:
        hero += f'<rect x="{x}" y="241" width="148" height="30" rx="7" fill="#0A1730" stroke="#315080"/>'
        hero += text(x+74, 261, label, 13, '#B9D6FF', 600, 'text-anchor="middle"')
    write('hero-banner.svg', 306, hero, 'Telex for macOS — Keep your eyes up. Find your flow.')
    for index, (slug, category, headline, cards) in enumerate(SECTIONS, 1):
        title = text(32, 34, f'{index:02d} / {category}', 12, '#60A5FA', 700, 'letter-spacing="2"')
        title += text(32, 75, headline, 29, weight=700)
        write(f'title-{slug}.svg', 102, title, f'{category}: {headline}')
        body = ''
        for col, (label, heading, lines) in enumerate(cards):
            x = 22 + col * 326
            body += f'<rect x="{x}" y="22" width="304" height="184" rx="12" fill="#090F1C" stroke="#233552"/>'
            body += text(x+17, 52, label, 10, '#60A5FA', 700, 'letter-spacing="1"')
            body += text(x+17, 87, heading, 18, weight=700)
            for row, line in enumerate(lines):
                body += text(x+17, 122+row*25, line, 13, '#A5B4CC')
        write(f'card-{slug}.svg', 228, body, ' / '.join(c[1] for c in cards))
    footer = text(500, 48, 'Telex for macOS', 25, weight=800, extra='text-anchor="middle"')
    footer += text(500, 78, 'Built for a little more eye contact. MIT licensed.', 15, '#60A5FA', extra='text-anchor="middle"')
    write('footer-signature.svg', 108, footer, 'Telex for macOS — MIT licensed')
    print(f'Generated 14 SVG assets in {OUT.relative_to(ROOT)}')

if __name__ == '__main__':
    main()
