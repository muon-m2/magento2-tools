# Magento 2 Module Review Report Template

# <Vendor_Module> Review

Review date: <YYYY-MM-DD>
Module path: `<path>`
Reviewer: Claude Code using `magento2-module-review`
Skill versions:

- magento2-module-review@2.2.3
- magento2-context@1.6.0

## Executive Summary

<Short summary of risk posture, major findings, and validation status.>

## Scope

- Module name:
- Path:
- Magento version hints:
- Feature surface:
- Review mode: Full / Quick
- Confidence: High (all files read) / Medium (key files read, others sampled) / Low (grep-scan only)
- Files fully read: <count or list>
- Files sampled: <count — opened but not exhaustively reviewed>
- Checklist areas skipped: <list area and reason, or "none">
- Known blind spots: <tools unavailable, surfaces not inspected, or "none">

## Findings

### <Severity>: <Finding Title>

Impact:
<Why this matters.>

Evidence:
`<file>:<line>` - <specific evidence>.

Recommendation:
<Concrete fix or mitigation.>

Verification:
<Test/static check/manual verification.>

## Architecture Checklist

| Area                       | Status           | Notes |
|----------------------------|------------------|-------|
| Registration and packaging | Pass/Fail/Review |       |
| Dependency injection       | Pass/Fail/Review |       |
| Service contracts and APIs | Pass/Fail/Review |       |
| Persistence and setup      | Pass/Fail/Review |       |
| Controllers and CSRF       | Pass/Fail/Review |       |
| Admin config and ACL       | Pass/Fail/Review |       |
| Frontend/templates         | Pass/Fail/Review |       |
| Security                   | Pass/Fail/Review |       |
| Performance                | Pass/Fail/Review |       |
| Testing                    | Pass/Fail/Review |       |
| Code style and PHPDoc      | Pass/Fail/Review |       |
| DRY/SOLID/KISS/SRP         | Pass/Fail/Review |       |
| Internationalisation       | Pass/Fail/Review |       |
| Content security policy    | Pass/Fail/Review |       |

## Tool Results

| Tool              | Result            | Command / Note |
|-------------------|-------------------|----------------|
| PHP lint          | Pass/Fail/Skipped |                |
| XML lint          | Pass/Fail/Skipped |                |
| JSON validation   | Pass/Fail/Skipped |                |
| Composer validate | Pass/Fail/Skipped |                |
| PHPCS Magento2    | Pass/Fail/Skipped |                |
| PHPMD             | Pass/Fail/Skipped |                |
| PHPStan/Psalm     | Pass/Fail/Skipped |                |
| PHPUnit           | Pass/Fail/Skipped |                |
| Semgrep/security  | Pass/Fail/Skipped |                |
| Magento CLI       | Pass/Fail/Skipped |                |

## Parallel Review Subtasks

Include this section only when subagents were explicitly authorized and used.

| Subtask                | Model / Agent | Scope | Result Summary |
|------------------------|---------------|-------|----------------|
| Architecture/API       |               |       |                |
| Security               |               |       |                |
| Frontend/admin         |               |       |                |
| Testing/tooling        |               |       |                |
| Performance/operations |               |       |                |

## Positive Observations

- <Observation>

## Recommended Next Steps

1. <Highest-value next step>
2. <Next step>

## Environment Limitations

- <Unavailable tool/runtime and impact>
