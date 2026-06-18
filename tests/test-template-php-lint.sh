#!/usr/bin/env bash
# Every .php template under skills/*/templates/ must pass `php -l` after
# substituting canonical placeholder values with valid PHP identifiers.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v php >/dev/null 2>&1; then
    echo "skip: php not on PATH"
    exit 0
fi

FAIL=0
while IFS= read -r tpl; do
    tmp="$(mktemp --suffix=.php)"
    sed -e 's/{Vendor}/Acme/g' \
        -e 's/{vendor}/acme/g' \
        -e 's/{Module}/Mod/g' \
        -e 's/{module}/mod/g' \
        -e 's/{ModuleName}/Mod/g' \
        -e 's/{VendorName}/Acme/g' \
        -e 's/{AttributeCode}/Attr/g' \
        -e 's/{attribute_code}/attr/g' \
        -e 's/{Attribute Label}/Label/g' \
        -e 's/{Code}/Code/g' \
        -e 's/{code}/code/g' \
        -e 's/{Entity}/Entity/g' \
        -e 's/{entity}/entity/g' \
        -e 's/{entities}/entities/g' \
        -e 's/{EntityName}/Entity/g' \
        -e 's/{BackendModelName}/SomeBackend/g' \
        -e 's/{BackendName}/Backend/g' \
        -e 's/{DefaultValue}/1/g' \
        -e 's/{FieldId}/some_field/g' \
        -e 's/{GroupId}/general/g' \
        -e 's/{SectionId}/acme_mod/g' \
        -e 's/{SourceName}/Source/g' \
        -e 's/{FrontendName}/Frontend/g' \
        -e 's/{ServiceName}/Service/g' \
        -e 's/{CommandClass}/RunCommand/g' \
        -e 's/{CommandName}/acme:mod:run/g' \
        -e 's/{command_name}/acme_mod_run/g' \
        -e 's/{CronJobName}/SyncJob/g' \
        -e 's/{cron_job_name}/acme_mod_sync/g' \
        -e 's/{ClassName}/Cls/g' \
        -e 's/{TestClassName}/Cls/g' \
        -e 's/{Method}/method/g' \
        -e 's/{method}/method/g' \
        -e 's/{ActionName}/Index/g' \
        -e 's/{ControllerName}/Index/g' \
        -e 's/{ControllerArea}/frontend/g' \
        -e 's/{ConsumerName}/Consumer/g' \
        -e 's/{JobName}/Job/g' \
        -e 's/{MessageName}/Message/g' \
        -e 's/{PatchName}/Patch/g' \
        -e 's/{Name}/Name/g' \
        -e 's/{DescriptiveName}/Service/g' \
        -e 's/{TargetNamespace}/Acme\\Mod/g' \
        -e 's/{TargetShortName}/Target/g' \
        -e 's/{description}/description/g' \
        -e 's/{action description}/action description/g' \
        -e 's/{Default Page Title}/Page Title/g' \
        -e 's/{Short description of what this service does}/Service summary/g' \
        -e 's/{ClassUnderTest}/UnitOfWork/g' \
        -e 's/{methodUnderTest}/doSomething/g' \
        -e 's/{SubNamespace}/Sub/g' \
        -e 's/{ShortDescription}/short/g' \
        -e 's/{ParentIdAccessor}/getParentId/g' \
        -e 's/{Patch}/Patch/g' \
        -e 's/{From}/from/g' \
        -e 's/{To}/to/g' \
        -e 's/{slug}/slug/g' \
        -e 's/{fixture}/fixture/g' \
        -e 's/{expected}/expected/g' \
        -e 's/{actual}/actual/g' \
        -e 's/{reproducedArgs}/null/g' \
        -e 's/{parent_id_key}/parent_id/g' \
        -e 's/{source_table}/src_tbl/g' \
        -e 's/{target_table}/tgt_tbl/g' \
        -e 's/{\$sourceTable}/\$srcTable/g' \
        -e 's/{\$targetTable}/\$tgtTable/g' \
        -e 's/{Symptom one-liner}/symptom/g' \
        -e 's/{short reminder}/reminder/g' \
        -e 's/{one-line description}/description/g' \
        -e 's/{frontend|adminhtml|webapi_rest}/frontend/g' \
        -e 's/{Area}/Index/g' \
        -e 's/{Controller}/Run/g' \
        -e 's/{Service}/SomeService/g' \
        -e 's/{Dep1FQCN}/stdClass/g' \
        -e 's/{Dep2FQCN}/stdClass/g' \
        -e 's/{Dep3FQCN}/stdClass/g' \
        -e 's/{TargetFqcn}/stdClass/g' \
        -e 's/{PluginName}/Plugin/g' \
        -e 's/{plugin_name}/acme_plugin/g' \
        -e 's/{ObserverName}/TrackOrderSave/g' \
        -e 's/{observer_name}/acme_observer/g' \
        -e 's/{PreferenceFor}/stdClass/g' \
        -e 's/{PreferenceForShort}/SomePreference/g' \
        -e 's/{SortOrder}/10/g' \
        -e 's/{EventName}/sales_order_save_after/g' \
        -e 's/{area}/frontend/g' \
        -e 's/{Dep1Type}/stdClass/g' \
        -e 's/{Dep2Type}/stdClass/g' \
        -e 's/{depMethod}/aMethod/g' \
        -e 's/{depReturn}/null/g' \
        -e 's/{args}//g' \
        -e 's/{invalidArgs}//g' \
        -e 's/{reproducedReturn}/null/g' \
        -e 's/{what fails before the fix}/before/g' \
        -e 's/{what passes after the fix}/after/g' \
        "$tpl" > "$tmp"
    result="$(php -l "$tmp" 2>&1)"
    if ! echo "$result" | grep -q 'No syntax errors detected'; then
        echo "FAIL: $tpl"
        echo "$result" | sed 's/^/    /'
        FAIL=1
    fi
    rm -f "$tmp"
done < <(find skills -path '*/templates/*.php' -type f)

exit "$FAIL"
