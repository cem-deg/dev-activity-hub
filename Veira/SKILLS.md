# SKILLS.md

This file defines the project-specific assistant responsibilities for Veira.

## Codex
Use Codex for:
- planning
- scope control
- project audit
- task definition
- documentation updates
- release-readiness guidance
- implementation handoff prompts
- small scoped fixes only when explicitly requested

When coding work should be done elsewhere, Codex must provide a direct English prompt and name the target agent.

## Claude Code
Use Claude Code as the primary coding implementation agent.

Claude Code should:
- implement within the approved scope
- follow PROJECT_CONTEXT.md, PROJECT_RULES.md, AGENTS.md, and CLAUDE.md
- avoid unrelated refactors
- keep changes small and reviewable
- surface implementation risks clearly

## Gemini
Use Gemini only for scoped review.

Gemini should:
- review against REVIEW_TEMPLATE.md and GEMINI_REVIEW_TEMPLATE.md
- classify issues by severity
- avoid redesigning the project
- avoid expanding scope

## Prompt Rules
- Prompts handed to other agents must be in English.
- Prompts must include scope, constraints, expected output, and files to check when known.
- Prompts must explicitly preserve Veira privacy, local-only behavior, and release-safety rules.

