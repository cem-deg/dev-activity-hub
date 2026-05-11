# REVIEW_TEMPLATE.md

Review the implementation strictly against:
- scope
- correctness
- privacy consistency
- tracking behavior
- idle handling
- regression risk
- maintainability within scope

Do not redesign the project unless a serious issue forces it.
Do not expand scope casually.

## Required Review Sections

### Critical Issues
Problems that break correctness, violate privacy expectations, violate scope severely, or create serious product risk.

### Medium Issues
Important issues that should likely be fixed before proceeding, but are not catastrophic.

### Minor Issues
Smaller concerns related to naming, clarity, maintainability, UI detail, or low-risk correctness gaps.

### Nice to Have
Optional improvements that are not required for approval.

### Regression Risk
State:
- Low / Medium / High
and explain why.

### Final Decision
Choose exactly one:
- Approved
- Approved with minor follow-up
- Needs revision
