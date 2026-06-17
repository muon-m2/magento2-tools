---
description: Deploy Magento 2 module(s) — pre-flight, ordered deploy, rollback (magento2-deploy)
argument-hint: "[--env=local|staging|production] [--validate-only] <modules>…"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-deploy` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not add `--auto`, `--i-know-what-im-doing`, or any other gate-bypassing flag. The skill's approval gate and production double-gate apply unchanged.
