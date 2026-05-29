# Maintenance Mode

When and how to enable Magento's maintenance flag during deploy.

## When to Enable

| Scenario | Maintenance mode |
|----------|-----------------|
| Production deploy | Always |
| Staging deploy with schema change | Yes |
| Staging deploy code-only | Optional |
| Local deploy | Never (slows iteration) |
| Hotfix on production with no schema change | Optional — depends on the change's risk |

## Whitelist for Maintenance Mode

Allow specific IPs to bypass maintenance (admin user, monitoring):

```bash
{magento_cli} maintenance:enable --ip={admin_ip} --ip={monitoring_ip}
```

The admin can still operate the back-office while maintenance is on for end users.

## Custom Maintenance Page

If the project has a custom maintenance page at `pub/errors/503.phtml`, it's served
automatically. To customize per deploy (e.g. include a back-online estimate), edit the
file before `maintenance:enable`:

```bash
echo '<p>Back online by {time}.</p>' >> pub/errors/503.phtml
```

Revert after `maintenance:disable`.

## Maintenance Mode During Failure

If a deploy fails with maintenance enabled:

1. Do NOT auto-disable. The site is in an inconsistent state.
2. Report the failure and ask the user: "Disable maintenance now (site goes live with
   partial deploy) or keep maintenance on while you remediate manually?"
3. Default to "keep maintenance on" — bias toward conservative behaviour.

## Maintenance Toggle Verification

After `maintenance:enable`, verify by curling the site:

```bash
curl -s -o /dev/null -w '%{http_code}\n' "{base_url}/"
```

Expect 503. If 200: the flag didn't take effect (permission issue or maintenance
whitelist matched the curl source). Investigate before proceeding.

After `maintenance:disable`, expect the same curl to return 200 (or 302 if there's a
default redirect).

## File System Path

`var/.maintenance.flag` is the on-disk indicator. The skill can fall back to:

```bash
touch var/.maintenance.flag    # enable
rm -f var/.maintenance.flag    # disable
```

if `maintenance:enable` fails due to PHP errors. The flag file is the source of truth.
