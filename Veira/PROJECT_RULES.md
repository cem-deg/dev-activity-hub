# PROJECT_RULES.md

## Core Principle
Veira must remain controlled, privacy-aware, and correctness-first.

## Priority Order
When tradeoffs appear, use this order:
1. correctness
2. privacy clarity
3. scope control
4. maintainability
5. polish
6. expansion

## Product Rules
- This project is macOS-only.
- This project is a menu bar + dashboard product.
- This project is local-first.
- Tracking must never start automatically on app launch.
- The user must explicitly start tracking from the menu bar.
- Launch at login does not imply auto-tracking.
- Idle must be represented separately.
- Per-app usage breakdowns must be explainable.
- Session state and reminder state must remain understandable to the user.

## V1 Scope Rules
Allowed in V1:
- active app tracking
- idle detection
- local persistence
- onboarding
- menu bar controls
- dashboard summaries
- settings
- update support

Not allowed in V1 unless explicitly approved:
- iOS support
- cloud sync
- URL tracking
- browser tab tracking
- window-title parsing
- AI-based categorization
- deep work intelligence
- speculative recommendation systems
- “smart” automation beyond defined scope

## Privacy Rules
- Do not implement keystroke logging.
- Do not implement screenshot capture.
- Do not implement content inspection.
- Do not imply invasive tracking in product copy.
- Do not request permissions that are not required for the approved scope.
- Any user-facing privacy text must be plain, explicit, and trustworthy.

## Tracking Rules
- Tracking correctness is product-critical.
- Idle handling is product-critical.
- Mouse, click, keyboard, and scroll behavior must be considered in design and implementation where relevant.
- Do not use weak or misleading heuristics without explicit approval.
- Do not silently treat ambiguous behavior as certainty.
- Prefer clear deterministic logic over speculative logic.

## Idle Rules
- Idle must be separable from active usage.
- Idle must appear in analytics rather than disappearing silently.
- Idle thresholds must remain user-controlled only within the approved set.
- Any future idle confirmation prompt requires explicit approval and is not default V1 behavior.

## App Identity and Insight Rules
- Use bundle identifier as the core app identity key.
- Per-app summaries must be deterministic.
- Session, idle, and reminder states must remain understandable to the user.
- Avoid hidden logic that makes insights hard to explain.

## Engineering Rules
- No random refactors.
- No unrelated file changes.
- No broad rewrites without approval.
- Keep changes scoped and reviewable.
- Separate UI logic from product logic when practical.
- Prefer modular and explicit structure.
- Prefer clarity over abstraction for its own sake.
- Do not introduce unnecessary dependencies.

## Workflow Rules
- Codex handles planning, scope control, task definition, audit, documentation updates, release-readiness guidance, and implementation handoff prompts.
- ChatGPT is no longer the main planning assistant for this project.
- Claude Code is the primary coding implementation agent.
- Gemini handles scoped review, risk analysis, and issue classification only.
- If implementation work belongs to another agent, Codex must provide a direct English prompt and identify the target agent.
- Any assisting agent must follow shared project context and output standards.

## Documentation Rules
Before implementation work grows, maintain:
- PROJECT_CONTEXT.md
- PROJECT_RULES.md
- AGENTS.md
- CLAUDE.md
- CODEX_TEMPLATE.md
- TASK_TEMPLATE.md
- REVIEW_TEMPLATE.md
- GEMINI_REVIEW_TEMPLATE.md
- REVIEW_LOG.md
- SKILLS.md
- any task-specific handoff notes as needed

## Output Rules
Every implementation response must include:
- Plan
- Changed Files
- What Was Done
- Risks
- Open Questions

Every review response must include:
- Critical Issues
- Medium Issues
- Minor Issues
- Nice to Have
- Regression Risk
- Final Decision

## Scope Discipline
When a task is narrowly scoped:
- solve the scoped problem
- do not redesign adjacent systems
- do not “improve” unrelated areas
- do not use the task as an excuse for cleanup elsewhere

## Escalation Rule
If a requested change would likely affect:
- tracking correctness
- idle correctness
- persistence correctness
- privacy model
- onboarding expectations
- product scope

then the agent must call it out explicitly in Risks or Open Questions instead of quietly proceeding.
