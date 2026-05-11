# ARCHITECTURE_OVERVIEW.md

## Veira Architecture Direction

This document is intentionally lightweight.
It exists to preserve architectural clarity while avoiding unnecessary rewrites.

## Product Shape
- macOS app
- menu bar utility
- dashboard window
- local-first persistence
- deterministic tracking pipeline

## Core Logical Layers
1. Tracking Layer
   - active app detection
   - tracking state
   - lifecycle events

2. Idle Layer
   - input-aware idle handling
   - threshold-based idle segmentation

3. Session and Insight Layer
   - session summaries
   - per-app breakdowns
   - daily and weekly insights

4. Persistence Layer
   - store sessions
   - store preferences
   - autosave and crash recovery

5. Presentation Layer
   - menu bar summary
   - dashboard summaries
   - onboarding
   - settings
   - update prompts

## Early Architectural Rules
- Do not merge all logic into UI views.
- Keep tracking logic separate from presentation logic.
- Keep persistence decisions local-first.
- Avoid architecture changes unless a scoped task justifies them.

## Current State
Implemented app in release-readiness / scoped maintenance mode.
Future architecture changes require explicit approval and clear risk notes.
