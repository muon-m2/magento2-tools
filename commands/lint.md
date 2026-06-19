---
description: Run the static-analysis gate (phpcs, phpstan, phpmd, php-cs-fixer, rector) and apply safe auto-fixes for a Magento 2 module (magento2-static-analysis).
argument-hint: "[--diff [ref]] [<Vendor>_<Module>]"
disable-model-invocation: true
---
Use the `magento2-tools:magento2-static-analysis` skill, forwarding these arguments verbatim: $ARGUMENTS

Do not bypass the Phase-2 approval gate before auto-fixes are applied; the skill's normal flow applies.
