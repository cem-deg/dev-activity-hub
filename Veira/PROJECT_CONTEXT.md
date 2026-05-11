# Veira

## Project Type
Veira is a minimal, privacy-first macOS menu bar app for session-based work tracking.

## Product Shape
The product is built as:
- a menu bar utility
- a dashboard window
- a local-first analytics tool

This is not a web app.
This is not an iPhone product.
This is not a cloud-first SaaS.

## Product Goal
Help users understand where their time goes across applications, sessions, and days by tracking active app usage, separating idle time, and presenting clear local-only summaries in a trustworthy way.

## Product Character
- developer-oriented
- privacy-aware
- practical
- premium
- utility-first
- explainable, not gimmicky

## Confirmed Product Decisions
- macOS only
- menu bar + dashboard
- local-only
- privacy-first
- tracking never starts automatically on app launch
- user must manually start tracking from the menu bar
- onboarding exists
- launch at login may be enabled
- launch at login must NOT imply auto-tracking
- active application tracking is core
- session duration tracking is core
- idle detection is core
- idle must be shown separately in analytics
- reminder timing must remain configurable
- update support is part of release readiness

## Core Features
- active app tracking
- idle detection
- app identity handling via bundle identifier
- today summary
- total tracked time
- app breakdown
- weekly view
- menu bar quick summary
- pause / resume tracking
- session timeline
- settings
- launch at login
- Sparkle update checks
- clear privacy-oriented onboarding

## V1 Non-Goals
- no iOS app
- no browser URL tracking
- no browser tab tracking
- no window-title parsing
- no content inspection
- no keystroke logging
- no screenshot capture
- no AI classification
- no “smart” activity inference that cannot be explained clearly
- no deep work intelligence unless explicitly approved
- no cloud sync

## Sensitive Product Areas
These areas are product-critical and must be treated carefully:
- idle detection correctness
- app tracking correctness
- session state correctness
- persistence correctness
- reminder and notification behavior
- update, signing, and release correctness
- privacy messaging
- menu bar control behavior

## Tracking Philosophy
Tracking correctness matters more than feature count.
Explainable behavior matters more than clever-looking behavior.
Privacy clarity matters more than aggressive automation.

## Current Phase
Release-ready maintenance and scoped evolution phase

## Immediate Objective
Keep project rules, workflow templates, and documentation aligned with the Codex planning / Claude Code implementation process before starting the next full audit or scoped implementation task.
