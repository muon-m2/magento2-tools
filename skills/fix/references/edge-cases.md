# Edge Cases

Part of the `fix` skill — read at Phase 1 onward, whenever the bug is in vendor/core code, spans modules, cannot be reproduced, or needs a schema/data/config-only change.

| Case                                                              | Behaviour                                                                                                                      |
|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Bug in vendor/ third-party module                                 | RCA proceeds; fix proposed as a plugin/observer in a project module, not as a vendor edit.                                     |
| Bug in Magento core                                               | Same: plugin/observer in a project module. Never edit `vendor/magento/`.                                                       |
| Bug spans ≥ 2 modules                                             | Per-task commits; RCA covers each module separately; one report.                                                               |
| Bug can't be reproduced                                           | Phase 2 fails after 2 attempts; report "cannot reproduce" with all evidence collected.                                         |
| Fix requires a **schema** change (`db_schema.xml`)                | Stop; redirect to `feature --mode=extend`. Bug-fix is for code-only changes.                                |
| Fix requires a **data** repair (correct corrupted rows, backfill) | Stays in-skill: write an idempotent data patch via `data-migration`; the regression test asserts the corrected state. |
| Bug is in a config file only                                      | Config/XSD-validation waiver applies (see Core Rules); document why no PHPUnit test in the RCA.                                |
