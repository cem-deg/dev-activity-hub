# Veira

A minimal, privacy-first macOS menu bar app for tracking how you actually spend your time.

Veira shows how your time is distributed across apps, sessions, and days — without leaving your machine or inspecting your work. — by app, by session, by day — without leaving your machine or reading anything you type.

---

## Features

- **Session tracking** — start and end work sessions manually from the menu bar
- **Active app tracking** — records which applications are in use during a session
- **Idle detection** — automatically pauses when you go inactive; resumes on your command
- **Live session state** — see the current session duration and top apps in real time from the menu bar
- **Daily summary** — total time and per-app breakdown for the current day
- **Weekly overview** — last 7 days of session history at a glance
- **Session history** — expandable session rows with per-app time breakdowns
- **Local persistence** — session data is saved to disk and survives app restarts
- **Onboarding** — a short first-launch flow that explains what is and isn't tracked

---

## How It Works

1. Click the menu bar icon and start a session
2. Work normally — Veira records which apps are active
3. If you step away, the session pauses automatically after a period of inactivity
4. Resume when you return, or end the session when you're done
5. Open the dashboard to review your day and the past week

---

## Privacy

Veira is built on a simple principle: track your time, not your work.

- No keystroke logging
- No screenshots
- No screen content capture
- No file or clipboard access
- No data is sent externally
- All data is stored locally in `~/Library/Application Support/Veira/`
- Nothing is synced, transmitted, or shared

The only thing Veira knows is which application was in the foreground and for how long.

---

## Tech Stack

- **Swift / SwiftUI** — UI and app lifecycle
- **AppKit** — menu bar integration, native window management
- **Core Graphics** — idle time detection via `CGEventSource`
- **UserNotifications** — inactivity pause notifications
- **JSON** — local session persistence via `Codable` + `FileManager`
- **XcodeGen** — project file generation from `project.yml`

---

## Status

Veira is an early but fully functional version. Core tracking, persistence, idle detection, and the dashboard are stable. The product is actively evolving.

---

## Development

**Requirements:** macOS 13+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/cem-deg/dev-activity-hub.git
cd dev-activity-hub/Veira
xcodegen generate
open Veira.xcodeproj
```

---

## Open Source

Veira is open source.

[github.com/cem-deg/dev-activity-hub](https://github.com/cem-deg/dev-activity-hub)
