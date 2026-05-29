# Multi-Environment Deploy Protocol

When deploying through multiple environments (local → staging → production), each
environment is its own deploy invocation gated on the previous one succeeding.

## Sequential Order

```
local → staging → production
```

Never deploy to production without staging first, unless the user explicitly skips with
`--skip-staging` AND `--i-know-what-im-doing`.

## Per-Environment Confirmation

After a successful local deploy:

> Local deploy succeeded. Promote to staging? (yes / no)

After a successful staging deploy:

> Staging deploy succeeded. Promote to production? (yes / no)

Each promotion is a separate `/magento2-deploy --env={next}` invocation. The skill does
NOT automatically chain.

## Diff Between Environments

For staging and production deploys, run a brief diff check:

```
git log {previous_env_tag}..{current_commit} --oneline
```

Present the commit list to the user before each promotion. Any new commits that weren't
in the previous-env deploy must be flagged explicitly.

## Production Approval Gate

For `--env=production`:

1. Confirm `--env=production` is intentional.
2. Show the diff from the last successful production deploy.
3. Show the plan (Phase 2 output).
4. Ask: "Snapshot before deploy? (recommended)".
5. Ask: "Confirm production deploy? Type 'deploy production'."

Only the exact string `deploy production` proceeds. Anything else cancels.

## Maintenance Window Communication

For production: ask the user whether a maintenance window should be announced first.
This skill does not send notifications — it asks the user to confirm they've handled
external communication.

## Tagging

After a successful production deploy:

```bash
git tag -a deploy/prod/{YYYY-MM-DD-HHMMSS} -m "Production deploy of {modules}"
```

Optional but recommended. The tag enables the next deploy to compute the diff.

## CI/CD Integration

When invoked from CI:

```
MAGENTO2_DEPLOY_NON_INTERACTIVE=1 /magento2-deploy --env=staging --auto {modules}
```

In non-interactive mode, the skill:
- Skips approval prompts (uses `--auto`).
- Refuses production deploys without `--i-know-what-im-doing`.
- Emits JSON reports for CI ingestion (`.docs/deployments/{ts}-{env}.json`).
- Exits non-zero on any failure.

## Per-Environment Configuration

Detect environment-specific settings from `CLAUDE.md`:

```
Deploy environments:
  - local:    docker compose exec -u magento php
  - staging:  ssh deploy@staging.example.com 'cd /var/www && php'
  - production: ssh deploy@prod.example.com 'cd /var/www && php'
```

Use these prefixes as the `runner` for that env, overriding the auto-detected context.

If no per-environment config is found, the deploy uses the local runner for every
environment — which is wrong for staging/prod. In that case, refuse to deploy to
non-local environments and instruct the user to add the config.
