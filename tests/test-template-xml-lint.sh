#!/usr/bin/env bash
# Every .xml template under skills/*/templates/ must parse as well-formed XML
# after substituting placeholders with valid identifiers. Catches accidental syntax
# breakage in module.xml, di.xml, acl.xml, layout XML, MFTF, etc.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v xmllint >/dev/null 2>&1; then
    echo "skip: xmllint not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.xml)"
    # Substitute the canonical placeholder schema plus the additional tokens used in
    # current XML templates. Kept in alphabetical-ish order to make additions easy.
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor_lower}/acme/g' \
        -e 's/{BackendModelName}/SomeBackend/g' \
        -e 's/{DefaultValue}/1/g' \
        -e 's/{FieldId}/some_field/g' \
        -e 's/{GroupId}/general/g' \
        -e 's/{SectionId}/acme_mod/g' \
        -e 's/{SourceName}/Source/g' \
        -e 's/{VENDOR_UPPER}/ACME/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        -e 's/{module_lower}/mod/g' \
        -e 's/{MODULE_UPPER}/MOD/g' \
        -e 's/{Entity}/Entity/g' \
        -e 's/{EntityName}/Entity/g' \
        -e 's/{entity}/entity/g' \
        -e 's/{entities}/entities/g' \
        -e 's/{entity_lower}/entity/g' \
        -e 's/{ENTITY_UPPER}/ENTITY/g' \
        -e 's/{Method}/method/g' \
        -e 's/{method_lower}/method/g' \
        -e 's/{Name}/Name/g' \
        -e 's/{name}/name/g' \
        -e 's/{action}/action/g' \
        -e 's/{ConsumerName}/Consumer/g' \
        -e 's/{consumer_description}/consumer/g' \
        -e 's/{JobName}/Job/g' \
        -e 's/{MessageName}/Message/g' \
        -e 's/{queue_name}/queue.name/g' \
        -e 's/{route}/index/g' \
        -e 's/{template_name}/template_name/g' \
        -e 's/{event_name}/event_name/g' \
        -e 's/{event_short_name}/event/g' \
        -e 's/{description}/description/g' \
        -e 's/{DescriptiveName}/Descriptive/g' \
        -e 's/{DESC}/desc/g' \
        -e 's/{TargetNamespace}/Acme\\Mod/g' \
        -e 's/{TargetShortName}/Target/g' \
        -e 's/{target_short_lower}/target/g' \
        -e 's/{Email Template Label}/Email Label/g' \
        -e 's/{CommandClass}/RunCommand/g' \
        -e 's/{command_name}/acme_mod_run/g' \
        -e 's/{CronJobName}/SyncJob/g' \
        -e 's/{cron_job_name}/acme_mod_sync/g' \
        -e 's/{CronGroup}/default/g' \
        -e 's/{Schedule}/*\/15 * * * */g' \
        "$tpl" > "$tmp"

    # MFTF templates use Magento's `{{_ENV.NAME}}` token, which is valid in MFTF DSL
    # but not in plain XML. Replace those with a harmless string before linting.
    sed -i 's/{{_ENV\.[^}]*}}/env_value/g; s/{{[^}]*}}/mftf_value/g' "$tmp"

    if ! xmllint --noout "$tmp" 2>/tmp/xml-lint.err; then
        echo "FAIL: $tpl"
        sed 's/^/    /' /tmp/xml-lint.err
        FAIL=1
    fi
    rm -f "$tmp" /tmp/xml-lint.err
done < <(find skills -path '*/templates/*.xml' -type f)

exit "$FAIL"
