# Audit Dimensions

The dimension catalogue `audit` fans out. Each row: what runs it, when it is included,
the `outputKind` it emits, and the model tier its dispatch pins (see `parallel-dispatch.md`).

| Dimension | Runner | Included when | outputKind | Tier |
|-----------|--------|---------------|-----------|------|
| Architecture / API review | `reviewer` agent (dimension: Architecture/API) | always | `review` | opus |
| Security review | `reviewer` agent (dimension: Security) | always | `review` | opus |
| Frontend/admin review | `reviewer` agent (dimension: Frontend/admin) | a `view/`, `ui_component/`, or controller surface exists | `review` | haiku |
| Testing/tooling review | `reviewer` agent (dimension: Testing/tooling) | always | `review` | haiku |
| Performance/ops review | `reviewer` agent (dimension: Performance/operations) | always | `review` | sonnet |
| Security scan | `security` `scripts/build-findings.sh` | always | `security` | haiku (scripted) |
| Performance scan | `perf-audit` `scripts/build-findings.sh` | always | `performance` | haiku (scripted) |
| Static analysis | `lint` `scripts/build-findings.sh` | always | `quality` | haiku (scripted) |
| Accessibility | `a11y-audit` `scripts/build-findings.sh` | storefront `.phtml` templates present | `accessibility` | haiku (scripted) |
| Breeze compatibility | `breeze-compat` `scripts/build-findings.sh` | Breeze theme active (`ctx.theme.breeze`) | `compatibility` | haiku (scripted) |
| Marketplace readiness | `marketplace` `scripts/build-findings.sh` | `--release-readiness`, or the request names Marketplace/EQP | `marketplace` | haiku (scripted) |

Notes:

- **Judgement vs scripted.** The five review dimensions need reasoning → `reviewer`
  subagents. The scripted scanners are deterministic → run their `build-findings.sh` directly (Bash);
  they need no LLM turn and already emit JSON+SARIF.
- **Security appears twice on purpose.** The scripted `security` catches CVEs, secrets,
  and cross-module patterns; the `reviewer` Security dimension catches localised code
  defects (ACL/CSRF/escaping/SQL). Consolidation de-duplicates any overlap by `file:line`.
- **`--include` / `--exclude`** override surface detection; record any forced change in the report.
- All runners receive `--docs-root=<output_root>` so their artifacts collect under one folder.
