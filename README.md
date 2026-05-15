# Veira

**A calm, private macOS app for understanding where your work time actually goes.**

Veira sits in your menu bar and tracks how your time is distributed across applications, sessions, and days — without reading your work, inspecting your screen, or sending your activity data off your machine.

---

## What Veira does

You start a session when you begin working. Veira observes which application is in the foreground and records how long it stays there. When you step away, it detects inactivity and pauses automatically. When you're done, you end the session.

That's the full model. Veira knows two things: which app was active, and for how long.

---

## Features

**Menu bar**
Live session status, today's tracked time, and your top apps from the current session — available from the menu bar without opening a window.

**Session controls**
Start, pause, resume, and end sessions manually. Veira never begins tracking automatically on launch or login.

**Idle detection**
Veira monitors for inactivity and pauses the session when you step away. A notification prompts you to resume when you return. The idle threshold and pause reminder interval are configurable in Settings.

**Daily view**
Today's total tracked time, a per-app usage breakdown, and an expandable session list showing exactly when you worked and what was in the foreground.

**Weekly view**
Seven days of session history with a day-by-day activity overview, session counts, and a drill-down to per-app detail for any day — including a donut chart breakdown.

**Insights**
Current streak, top app today, longest session, and most active day of the week. All computed locally from your own data.

**Automatic updates**
Veira checks for new releases and notifies you in-app. Updates are delivered as signed, notarized packages via Sparkle.

---

## Privacy

Veira is designed around one constraint: track time, not work.

| What Veira records | What Veira never records |
|---|---|
| Application name | Window title or content |
| Time in foreground | Keystrokes or mouse clicks |
| Session start and end | Screenshots or screen capture |
| Idle periods | Browser URLs, files, or clipboard |

All session data is stored locally in `~/Library/Application Support/Veira/`. Nothing is uploaded, synced, or transmitted. Update checks contact GitHub only to fetch release metadata — no usage data is included.

---

## How it works

1. Click the Veira icon in the menu bar and press **Start Session**.
2. Work normally. Veira records which app is in the foreground.
3. Step away — Veira detects inactivity and pauses the session.
4. Resume when you're back, or end the session when you're done.
5. Open the dashboard to review today's breakdown and the past week.

---

## Installation

Download the latest release from [github.com/cem-deg/Veira-activity-menubar/releases](https://github.com/cem-deg/Veira-activity-menubar/releases). Open the DMG, drag Veira to your Applications folder, and launch it.

**System requirement:** macOS 14 (Sonoma) or later.

Veira is distributed as a Developer ID–signed and Apple-notarized application. It is not available through the Mac App Store.

**Automatic updates** — Veira will notify you when a new version is available. Updates can be installed directly from the app.

---

## Your data

Session data is stored as a single JSON file:

```
~/Library/Application Support/Veira/workdays.json
```

The file is human-readable. It never leaves your machine.

---

## Development

**Requirements:** macOS 14+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/cem-deg/Veira-activity-menubar.git
cd Veira-activity-menubar/Veira
xcodegen generate
open Veira.xcodeproj
```

The Xcode project is generated from `Veira/project.yml` via XcodeGen. When changing project settings, update `project.yml` first, then regenerate `Veira.xcodeproj`.

---

## Distribution

Releases are published at [github.com/cem-deg/Veira-activity-menubar/releases](https://github.com/cem-deg/Veira-activity-menubar/releases) as notarized DMG files, signed with a Developer ID Application certificate. In-app updates are delivered through a Sparkle appcast hosted at the same repository.

---

## Open source

Veira is open source. Contributions, issue reports, and feedback are welcome.

[github.com/cem-deg/Veira-activity-menubar](https://github.com/cem-deg/Veira-activity-menubar)
