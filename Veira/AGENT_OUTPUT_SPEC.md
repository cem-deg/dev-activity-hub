# AGENT_OUTPUT_SPEC.md

This file standardizes communication for the Codex-planned, Claude Code-implemented workflow, including any scoped Gemini review.

## Goal
All agent outputs must be:
- short enough to scan
- structured enough to hand off
- explicit enough to review
- consistent enough for multi-agent workflows

## Implementation Output Standard
Every implementation-oriented agent response must use:

### Plan
3–5 steps max

### Changed Files
List every changed file explicitly

### What Was Done
Concrete summary of actual changes

### Risks
State product, technical, or regression risks

### Open Questions
Only when necessary

## Review Output Standard
Every review-oriented agent response must use:

### Critical Issues
### Medium Issues
### Minor Issues
### Nice to Have
### Regression Risk
### Final Decision

## Severity Guidance

### Critical
Use only if:
- core product correctness breaks
- privacy expectations are violated
- scope is severely violated
- tracking or persistence behavior becomes unreliable
- the change should not ship as-is

### Medium
Use if:
- an important issue exists
- the implementation likely needs follow-up before continuing
- behavior is wrong or fragile, but not catastrophic

### Minor
Use if:
- the issue is real but low-risk
- mostly clarity, naming, small logic, or maintainability

### Nice to Have
Use only for optional improvements that should not block progress

## Handoff Rule
When handing work from Codex to Claude Code, from Codex to a scoped reviewer, or returning results to Codex:
- preserve section headings
- do not collapse risks into vague summaries
- do not hide uncertainty
- do not reframe approved scope without explanation

## Anti-Pattern Rule
Avoid:
- giant unstructured paragraphs
- vague “everything looks good” reviews
- hidden scope expansion
- undocumented assumptions
- ambiguous risk language
