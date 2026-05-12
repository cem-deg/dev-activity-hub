We are continuing an existing structured product project.

# Project
Veira

# Product Summary
Veira is a minimal, privacy-first macOS menu bar app for session-based work tracking.

The product tracks active applications, session durations, idle time, and pause/idle reminder states, then presents calm daily and weekly insights without inspecting user content or sending data externally.

# Confirmed Product Decisions
- macOS only
- menu bar + dashboard
- local-only
- privacy-first
- onboarding exists
- settings exist
- launch at login may exist
- launch at login does not imply auto-tracking
- tracking must never auto-start on app launch
- user manually starts tracking from the menu bar
- active app tracking is core
- idle detection is core
- idle must appear separately in analytics
- reminder timing is user-configurable
- Sparkle update support exists
- Developer ID signing, notarization, DMG distribution, GitHub Releases, and appcast.xml are part of release readiness

# Implemented Product Areas
- session start / pause / resume / end
- dashboard and menu bar controls
- idle detection
- paused-but-active notifications
- configurable reminder timings
- daily and weekly summaries
- weekly heatmap and day details
- per-app usage breakdown
- donut charts and hover tooltips
- session timeline
- streak badge and quick insights
- settings screen
- launch at login
- Sparkle update checks and update notifications
- autosave, crash recovery, safe JSON loading, serialized async persistence writes
- Developer ID signing and notarization flow

# Non-Goals / Guardrails
- no iOS app
- no cloud sync
- no URL tracking
- no browser tab tracking
- no window-title parsing
- no content inspection
- no keystroke logging
- no screenshot capture
- no AI classification unless explicitly approved
- no deep work intelligence unless explicitly approved
- no architecture rewrites without approval

# Critical Product Priorities
1. tracking correctness
2. idle correctness
3. persistence correctness
4. privacy trust
5. scope control
6. release correctness

# Workflow Roles
- Codex = primary planning, scope control, task definition, audit, documentation updates, release-readiness guidance, and implementation handoff prompts
- Claude Code = primary coding implementation agent
- Gemini = scoped review only
- ChatGPT = no longer the main planning assistant

# Working Rules
- do not expand scope
- do not refactor unrelated code
- correctness before polish
- deterministic behavior over speculative behavior
- privacy clarity must remain strong
- idle handling is product-critical
- persistence and release correctness are product-critical
- all outputs should follow the project templates
- if implementation work belongs to another agent, provide a direct English prompt and name the target agent

# Current Phase
Release-ready maintenance and scoped evolution after Developer ID signed/notarized DMG distribution.

# Immediate Goal
Continue approved post-release audit follow-ups with scoped, low-risk fixes. Do not start new product features without explicit approval.
