# PCI Context

When findings elevate PCI scope. PCI scope = code paths that handle cardholder data
(PAN, CVV, expiry, cardholder name + PAN, etc.).

## In-Scope Indicators

A module or file is in PCI scope if it:

- Touches `Magento\Payment\Model\Method\*`
- Touches `quote_payment` or `sales_order_payment` tables
- Receives card data via REST/GraphQL (full PAN or CVV)
- Implements `Magento\Payment\Gateway\*` interfaces
- Stores card data (even tokenized — depends on tokenizer scope)

## How Findings Elevate

| Finding category | Default severity | PCI bump |
|-----------------|------------------|----------|
| Anonymous REST returning order/payment data | High | Critical |
| Missing TLS check in payment integration | Medium | High |
| Hardcoded API key for payment gateway | High | Critical |
| Card data logged in plain text | High | Critical |
| Plugin on `Magento\Payment\Model\InfoInterface::getData()` | Medium | High |
| Custom encryption (not Magento Crypt) on cardholder data | Medium | High |

## PCI Scope Flag

The audit emits a `pciScope: true` flag on findings touching PCI-relevant paths. The
flag is used in:

- Report's executive summary ("This audit identified N PCI-scope findings; remediation
  is required before production.")
- Severity bumping (see table above)
- Recommended next steps ("Coordinate remediation with the QSA.")

## Detection

```bash
grep -rE 'Magento\\Payment\\Method|quote_payment|sales_order_payment|Gateway\\(Command|Config|Http|Response|Validator)' \
    {ctx.magento_root}/app/code/{Vendor}/{Module}
```

Any match flags the module as PCI-touched.

## What to Recommend

For each PCI-scope finding, the recommendation must include:

- The remediation step
- A note that the change is PCI-significant and must be reviewed before deploy
- A pointer to the project's PCI policy or QSA contact (placeholder if not configured)

## PCI Scope Reduction

If the module can avoid PCI scope by delegating to a tokenizer (Stripe, Adyen, Braintree),
recommend that path explicitly. Reducing PCI scope is usually preferable to passing more
of it.
