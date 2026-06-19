# CI Integration

Running `magento2-static-analysis` as an automated CI gate: exit codes, SARIF upload,
PR gating via `--diff`, and the quality threshold contract.

## Exit Code Contract

| Condition | Exit code |
|-----------|-----------|
| No residual violations | 0 |
| Residual Low / Info violations only | 0 (informational) |
| Residual Medium violations | 0 by default; 1 with `--strict` |
| Residual High violations | 1 |
| Residual Critical violations | 1 |
| Tool runtime error (not a violation) | 2 |

`build-findings.sh` exits 0 always (it only builds artifacts). The CI caller must read
`summary.bySeverity` from the output JSON and apply the exit-code logic above.

```bash
#!/usr/bin/env bash
# Example CI step
TARGET_MODULE="Acme_OrderExport" \
TARGET_PATH="src/app/code/Acme/OrderExport" \
SCOPE="module" \
OUTPUT_DIR=".docs/quality" \
bash skills/magento2-static-analysis/scripts/build-findings.sh > /dev/null

JSON=".docs/quality/quality-module-$(date -u +%Y-%m-%d).json"
python3 - "$JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
sev = d.get('summary', {}).get('bySeverity', {})
if sev.get('critical', 0) + sev.get('high', 0) > 0:
    print(f"FAIL: {sev.get('critical',0)} critical, {sev.get('high',0)} high violations")
    sys.exit(1)
print("Quality gate passed")
PY
```

## PR Gating with --diff

Restrict analysis to the changed files in a PR to keep CI fast:

```bash
# In .github/workflows/quality.yml
- name: Static analysis (changed files only)
  run: |
    SCOPE=diff \
    DIFF_REF=origin/main \
    TARGET_MODULE="${{ env.MODULE }}" \
    TARGET_PATH="${{ env.MODULE_PATH }}" \
    OUTPUT_DIR=".docs/quality" \
    bash skills/magento2-static-analysis/scripts/run-analysis.sh \
      --diff origin/main "${{ env.MODULE_PATH }}"
```

`run-analysis.sh` passes `--diff origin/main` to each underlying tool where supported:
- `phpcs`: pass the changed file list explicitly
- `phpstan`: pass the changed file list explicitly
- `phpmd`: pass the changed file list explicitly (phpmd does not natively diff-scope)
- `rector --dry-run`: pass the changed file list explicitly

## SARIF Upload to GitHub Code Scanning

The `build-findings.sh` emitter produces a SARIF 2.1.0 file alongside the JSON. Upload it
with the standard GitHub action:

```yaml
# .github/workflows/quality.yml
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run static analysis
        run: |
          TARGET_MODULE="Acme_OrderExport" \
          TARGET_PATH="src/app/code/Acme/OrderExport" \
          SCOPE=module \
          OUTPUT_DIR=.docs/quality \
          bash skills/magento2-static-analysis/scripts/build-findings.sh > /dev/null

      - name: Upload SARIF to GitHub Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: .docs/quality/quality-module-${{ env.DATE }}.sarif
          category: magento2-static-analysis
```

The SARIF file maps Critical/High findings to `error` level, Medium to `warning`, and
Low/Info to `note`, matching GitHub Code Scanning's display conventions.

## Makefile / composer scripts Integration

```makefile
# Makefile
quality:
	@TARGET_MODULE=Acme_OrderExport \
	 TARGET_PATH=src/app/code/Acme/OrderExport \
	 SCOPE=module \
	 OUTPUT_DIR=.docs/quality \
	 bash skills/magento2-static-analysis/scripts/build-findings.sh > /dev/null
	@python3 scripts/check-quality-gate.py .docs/quality/quality-module-$$(date -u +%Y-%m-%d).json
```

```json
// composer.json scripts
{
  "scripts": {
    "quality": "bash skills/magento2-static-analysis/scripts/build-findings.sh",
    "quality:fix": "bash skills/magento2-static-analysis/scripts/apply-fixes.sh"
  }
}
```

## Caching

Tool outputs are not cached across CI runs — always re-run the full analysis for
correctness. However, the SARIF file written to `.docs/quality/` can be archived as a CI
artifact for historical comparison.

```yaml
- name: Archive quality artifacts
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: quality-report-${{ github.sha }}
    path: .docs/quality/
    retention-days: 90
```
