# Audit Dimensions

The dimension catalogue `magento2-audit` fans out. Each row: what runs it, when it is included,
the `outputKind` it emits, and its advisory model tier (see `parallel-dispatch.md`).

| Dimension | Runner | Included when | outputKind | Tier |
|-----------|--------|---------------|-----------|------|
| Architecture / API review | `magento2-reviewer` agent (dimension: Architecture/API) | always | `review` | session |
| Security review | `magento2-reviewer` agent (dimension: Security) | always | `review` | session/opus |
| Frontend/admin review | `magento2-reviewer` agent (dimension: Frontend/admin) | a `view/`, `ui_component/`, or controller surface exists | `review` | haiku |
| Testing/tooling review | `magento2-reviewer` agent (dimension: Testing/tooling) | always | `review` | haiku |
| Performance/ops review | `magento2-reviewer` agent (dimension: Performance/operations) | always | `review` | session |
| Security scan | `magento2-security-audit` `scripts/build-findings.sh` | always | `security` | haiku (scripted) |
| Performance scan | `magento2-performance-audit` `scripts/build-findings.sh` | always | `performance` | haiku (scripted) |
| Static analysis | `magento2-static-analysis` `scripts/build-findings.sh` | always | `quality` | haiku (scripted) |
| Accessibility | `magento2-accessibility-audit` `scripts/build-findings.sh` | storefront `.phtml` templates present | `accessibility` | haiku (scripted) |
| Breeze compatibility | `magento2-breeze-compat-audit` `scripts/build-findings.sh` | Breeze theme active (`ctx.theme.breeze`) | `compatibility` | haiku (scripted) |
| Marketplace readiness | `magento2-marketplace-prep` `scripts/build-findings.sh` | `--release-readiness`, or the request names Marketplace/EQP | `marketplace` | haiku (scripted) |

Notes:

- **Judgement vs scripted.** The five review dimensions need reasoning → `magento2-reviewer`
  subagents. The scripted scanners are deterministic → run their `build-findings.sh` directly (Bash);
  they need no LLM turn and already emit JSON+SARIF.
- **Security appears twice on purpose.** The scripted `magento2-security-audit` catches CVEs, secrets,
  and cross-module patterns; the `magento2-reviewer` Security dimension catches localised code
  defects (ACL/CSRF/escaping/SQL). Consolidation de-duplicates any overlap by `file:line`.
- **`--include` / `--exclude`** override surface detection; record any forced change in the report.
- All runners receive `--docs-root=<output_root>` so their artifacts collect under one folder.
