#!/usr/bin/env bash
# Every `urn:magento:...` schema URN shipped under skills/ (and the generated-module
# fixtures) must appear in the verified allowlist below.
#
# test-template-xml-lint.sh proves a template is well-formed XML, but xmllint never
# resolves `xsi:noNamespaceSchemaLocation`. A URN pointing at an .xsd that does not
# exist is therefore invisible to it — Magento only fails at runtime, with
# "Could not find schema file" on cache flush / setup:upgrade. Three dangling URNs
# shipped that way before this test existed.
#
# Adding a URN here is deliberate: verify the target file exists in magento/magento2
# FIRST, then add it. Resolution rules (Magento\Framework\Config\Dom\UrnResolver):
#
#   urn:magento:framework:X/etc/Y.xsd        -> lib/internal/Magento/Framework/X/etc/Y.xsd
#   urn:magento:framework-message-queue:etc/Y.xsd
#                                            -> lib/internal/Magento/Framework/MessageQueue/etc/Y.xsd
#   urn:magento:module:Magento_X:etc/Y.xsd   -> app/code/Magento/X/etc/Y.xsd
#   urn:magento:mftf:X/etc/Y.xsd             -> magento2-functional-testing-framework
#                                               src/Magento/FunctionalTestingFramework/X/etc/Y.xsd
#
# Do not infer a URN from the config file's name or from the module that owns the
# feature — several schemas live somewhere non-obvious. Known traps, all previously
# shipped wrong:
#
#   config.xml        -> Magento_Store, NOT framework:App    (App/etc has no config.xsd)
#   communication.xml -> framework:Communication, NOT MessageQueue/framework-message-queue
#   adminhtml routes.xml -> framework:App, NOT Magento_Backend (same URN as frontend)
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Verified against magento/magento2 2.4-develop.
KNOWN_URNS=(
    urn:magento:framework:Acl/etc/acl.xsd
    urn:magento:framework:Api/etc/extension_attributes.xsd
    urn:magento:framework:App/etc/routes.xsd
    urn:magento:framework:Communication/etc/communication.xsd
    urn:magento:framework:Config/etc/theme.xsd
    urn:magento:framework:Config/etc/view.xsd
    urn:magento:framework:Event/etc/events.xsd
    urn:magento:framework:Indexer/etc/indexer.xsd
    urn:magento:framework:Module/etc/module.xsd
    urn:magento:framework:Mview/etc/mview.xsd
    urn:magento:framework:ObjectManager/etc/config.xsd
    urn:magento:framework:Setup/Declaration/Schema/etc/schema.xsd
    urn:magento:framework:View/Layout/etc/page_configuration.xsd
    urn:magento:framework-message-queue:etc/consumer.xsd
    urn:magento:framework-message-queue:etc/publisher.xsd
    urn:magento:framework-message-queue:etc/topology.xsd
    urn:magento:mftf:Page/etc/PageObject.xsd
    urn:magento:mftf:Page/etc/SectionObject.xsd
    urn:magento:mftf:Test/etc/actionGroupSchema.xsd
    urn:magento:mftf:Test/etc/testSchema.xsd
    urn:magento:module:Magento_Backend:etc/menu.xsd
    urn:magento:module:Magento_Config:etc/system_file.xsd
    urn:magento:module:Magento_Cron:etc/crontab.xsd
    urn:magento:module:Magento_Email:etc/email_templates.xsd
    urn:magento:module:Magento_Store:etc/config.xsd
    urn:magento:module:Magento_Ui:etc/ui_configuration.xsd
    urn:magento:module:Magento_Webapi:etc/webapi.xsd
)

is_known() {
    local candidate="$1" known
    for known in "${KNOWN_URNS[@]}"; do
        [ "$candidate" = "$known" ] && return 0
    done
    return 1
}

# `grep -roE` emits `<path>:<match>`; the match always begins at `urn:magento:`.
FAIL=0
while IFS= read -r hit; do
    file="${hit%%:urn:magento:*}"
    urn="urn:magento:${hit#*:urn:magento:}"
    if ! is_known "$urn"; then
        echo "FAIL: $file"
        echo "    unverified URN: $urn"
        echo "    Confirm the .xsd exists in magento/magento2, then add it to KNOWN_URNS."
        FAIL=1
    fi
done < <(grep -roE "urn:magento:[A-Za-z0-9_:/.-]+" skills tests/fixtures 2>/dev/null | sort -u)

exit "$FAIL"
