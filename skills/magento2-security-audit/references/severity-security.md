# Security Audit Severity Calibration

Extends the shared severity scale (`magento2-context/references/severity.md`) with
security-specific anchors.

## Calibration Matrix

| Severity | Examples |
|----------|----------|
| Critical | • RCE-class CVE in a direct dependency<br>• Secret committed to git<br>• Payment data path without auth<br>• `eval()` on user-controlled input<br>• Hardcoded encryption key |
| High | • Anonymous REST endpoint returning non-public data<br>• Missing CSRF on admin POST<br>• CVE in indirect dependency with no upgrade available<br>• Card data logged in plain text<br>• `<preference>` on a payment class without documented justification |
| Medium | • Missing CSP for module loading external JS<br>• Weak session cookie flags (no `secure`)<br>• `<preference>` on `Customer\Model\Session`<br>• Wildcard ACL ID |
| Low | • Unused encrypted backend model on a sensitive field<br>• ACL granularity could be finer<br>• Missing rate limit on non-sensitive endpoint |
| Info | • EQP style finding (missing `LICENSE.txt`)<br>• Secret scan skipped (tool unavailable)<br>• Magento version is 2.4.6-p3 (latest is 2.4.6-p8) |

## PCI Scope Bumps

See `pci-context.md`. Findings touching cardholder data paths get +1 severity step (Medium
→ High, High → Critical).

## GDPR Bumps

Findings touching personal data (customer email, address, billing details, IP logs) get
+1 severity step when:
- Data is stored without encryption
- Data is logged for longer than necessary
- Data is sent to a third party without explicit consent flow
- Data retention policy isn't enforced (no scheduled deletion)

See `pci-context.md` for the analogous treatment.

## Why a Finding Is Critical (Anchoring Test)

Before marking a finding Critical, confirm:
- It allows code execution, data exfiltration, or auth bypass.
- A motivated attacker could exploit it within 1 hour given the audit report.
- Fix requires action **before** production deployment.

If any of these is no, it's at most High.

## Calibration Drift

When a new pattern is added to the audit, calibrate by:
1. Comparing severity to 2-3 known anchors above.
2. Asking: "If I were on call, would this finding wake me up?"
3. If yes for High/Critical — confirm; else — bump down to Medium/Low.

The shared severity scale is the source of truth — these anchors extend, not replace.
