#!/usr/bin/env bash
# =============================================================================
# Create the directory structure for a new Magento 2 module.
#
# Usage:
#   ./scripts/create-dirs.sh VendorName ModuleName [surface...]
#
# VendorName — PascalCase vendor prefix (e.g. Acme). Derived from CLAUDE.md or provided by the
#              skill after resolving context; never hardcoded.
#
# Surfaces:
#   core (always included), persistence, service_contracts, admin_config,
#   admin_ui, frontend_ui, rest_api, graphql, cron, queue
#
# Environment (optional):
#   MODULE_DIR  Module directory root. Defaults to `src/app/code` when src/ exists,
#               otherwise `app/code`. The value from magento2-context's `module_dir`
#               field should be exported by callers.
#
# Example:
#   ./scripts/create-dirs.sh Acme OrderExport persistence service_contracts admin_ui
#   MODULE_DIR=app/code ./scripts/create-dirs.sh Acme OrderExport core
# =============================================================================
set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" ]]; then
    echo "Usage: $0 <VendorName> <ModuleName> [surface...]" >&2
    echo "" >&2
    echo "  VendorName  PascalCase vendor prefix (from CLAUDE.md or project context)" >&2
    echo "  ModuleName  PascalCase module name" >&2
    echo "  Surfaces:   core persistence service_contracts admin_config" >&2
    echo "              admin_ui frontend_ui rest_api graphql cron queue" >&2
    echo "" >&2
    echo "  Env: MODULE_DIR overrides the module root (default: auto-detect)." >&2
    exit 1
fi

VENDOR="$1"
MODULE_NAME="$2"

# Determine module root. Honour MODULE_DIR if supplied; otherwise auto-detect.
if [[ -z "${MODULE_DIR:-}" ]]; then
    if [[ -d "src/app/code" ]]; then
        MODULE_DIR="src/app/code"
    elif [[ -d "app/code" ]]; then
        MODULE_DIR="app/code"
    else
        echo "Error: cannot find a module directory ('src/app/code' or 'app/code')." >&2
        echo "  Pass MODULE_DIR=<path> or run from a Magento project root." >&2
        echo "  Current directory: $(pwd)" >&2
        exit 1
    fi
fi

if [[ ! -d "$MODULE_DIR" ]]; then
    echo "Error: MODULE_DIR='${MODULE_DIR}' does not exist." >&2
    exit 1
fi

MODULE_PATH="${MODULE_DIR}/${VENDOR}/${MODULE_NAME}"

# --- Validate vendor name ---
if ! [[ "$VENDOR" =~ ^[A-Z][a-zA-Z]{1,49}$ ]]; then
    echo "Error: VendorName must be PascalCase, letters only, 2–50 characters." >&2
    exit 1
fi

# --- Validate module name ---
if ! [[ "$MODULE_NAME" =~ ^[A-Z][a-zA-Z]{1,49}$ ]]; then
    echo "Error: ModuleName must be PascalCase, letters only, 2–50 characters." >&2
    echo "  Valid:   OrderExport, CustomerSegment, ConnectorCore" >&2
    echo "  Invalid: order_export, 123Module, helper" >&2
    exit 1
fi

# --- Check for existing module ---
# Accept --augment as a flag to allow adding surfaces to an existing module.
AUGMENT=false
shift 2
SURFACES=()
for arg in "$@"; do
    if [[ "$arg" == "--augment" ]]; then
        AUGMENT=true
    else
        SURFACES+=("$arg")
    fi
done

if [[ -d "$MODULE_PATH" ]]; then
    if [[ "$AUGMENT" != "true" ]]; then
        echo "Error: ${VENDOR}_${MODULE_NAME} already exists at ${MODULE_PATH}" >&2
        echo "  Pass --augment to add surfaces to an existing module." >&2
        exit 1
    fi
    echo "Augment mode: adding surfaces to existing ${VENDOR}_${MODULE_NAME}"
fi

# Default to core if no surfaces given
if [[ ${#SURFACES[@]} -eq 0 ]]; then
    SURFACES=("core")
fi

# --- Helper: check if a surface is declared ---
has_surface() {
    local s
    for s in "${SURFACES[@]}"; do
        [[ "$s" == "$1" ]] && return 0
    done
    return 1
}

# --- Helper: add surface if not already present ---
add_surface() {
    has_surface "$1" || SURFACES+=("$1")
}

# --- Auto-resolve surface dependencies ---
has_surface "persistence" && add_surface "service_contracts"
has_surface "admin_ui"    && add_surface "admin_config"
has_surface "rest_api"    && add_surface "service_contracts"
has_surface "graphql"     && add_surface "service_contracts"
( has_surface "admin_ui" || has_surface "frontend_ui" ) && add_surface "i18n"

echo "Scaffolding ${VENDOR}_${MODULE_NAME}"
echo "Path: ${MODULE_PATH}"
echo "Surfaces: ${SURFACES[*]}"
echo ""

# =============================================================================
# Core — always created
# =============================================================================
mkdir -p "${MODULE_PATH}/etc"
echo "  ✓ core       (etc/)"

# =============================================================================
# Persistence
# =============================================================================
if has_surface "persistence"; then
    mkdir -p "${MODULE_PATH}/Model/ResourceModel"
    mkdir -p "${MODULE_PATH}/Setup/Patch/Data"
    echo "  ✓ persistence (Model/, Model/ResourceModel/, Setup/Patch/Data/)"
fi

# =============================================================================
# Service Contracts
# =============================================================================
if has_surface "service_contracts"; then
    mkdir -p "${MODULE_PATH}/Api/Data"
    mkdir -p "${MODULE_PATH}/Service"
    echo "  ✓ service_contracts (Api/, Api/Data/, Service/)"
fi

# =============================================================================
# Admin Config
# =============================================================================
if has_surface "admin_config"; then
    mkdir -p "${MODULE_PATH}/etc/adminhtml"
    echo "  ✓ admin_config (etc/adminhtml/)"
fi

# =============================================================================
# Admin UI
# =============================================================================
if has_surface "admin_ui"; then
    mkdir -p "${MODULE_PATH}/Controller/Adminhtml"
    mkdir -p "${MODULE_PATH}/view/adminhtml/layout"
    mkdir -p "${MODULE_PATH}/view/adminhtml/templates"
    mkdir -p "${MODULE_PATH}/view/adminhtml/ui_component"
    mkdir -p "${MODULE_PATH}/Ui/Component/Listing/Column"
    mkdir -p "${MODULE_PATH}/Ui/DataProvider"
    echo "  ✓ admin_ui (Controller/Adminhtml/, view/adminhtml/, Ui/Component/, Ui/DataProvider/)"
fi

# =============================================================================
# Frontend UI
# =============================================================================
if has_surface "frontend_ui"; then
    mkdir -p "${MODULE_PATH}/Controller"
    mkdir -p "${MODULE_PATH}/view/frontend/layout"
    mkdir -p "${MODULE_PATH}/view/frontend/templates"
    mkdir -p "${MODULE_PATH}/ViewModel"
    echo "  ✓ frontend_ui (Controller/, view/frontend/, ViewModel/)"
fi

# =============================================================================
# REST API — no extra dirs; webapi.xml lives in etc/
# =============================================================================
if has_surface "rest_api"; then
    echo "  ✓ rest_api (etc/webapi.xml — no extra dirs)"
fi

# =============================================================================
# GraphQL
# =============================================================================
if has_surface "graphql"; then
    mkdir -p "${MODULE_PATH}/Model/Resolver/Mutation"
    mkdir -p "${MODULE_PATH}/Model/Resolver/Batch"
    echo "  ✓ graphql (Model/Resolver/, Model/Resolver/Mutation/, Model/Resolver/Batch/)"
fi

# =============================================================================
# Cron
# =============================================================================
if has_surface "cron"; then
    mkdir -p "${MODULE_PATH}/Cron"
    echo "  ✓ cron (Cron/)"
fi

# =============================================================================
# Queue
# =============================================================================
if has_surface "queue"; then
    mkdir -p "${MODULE_PATH}/Model/Consumer"
    echo "  ✓ queue (Model/Consumer/)"
fi

# =============================================================================
# i18n (auto-included with UI surfaces)
# =============================================================================
if has_surface "i18n"; then
    mkdir -p "${MODULE_PATH}/i18n"
    echo "  ✓ i18n (i18n/)"
fi

# =============================================================================
# Tests (always included for non-vendor modules)
# =============================================================================
mkdir -p "${MODULE_PATH}/Test/Unit"
mkdir -p "${MODULE_PATH}/Test/Integration"
echo "  ✓ tests (Test/Unit/, Test/Integration/)"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "Directory structure:"
find "${MODULE_PATH}" -type d | sort | sed "s|${MODULE_PATH}|  ${MODULE_PATH}|"
echo ""
echo "Next: generate implementation files for each surface."
echo ""
echo "Note: entity-specific subdirectories (Model/ResourceModel/{Entity}/,"
echo "  Controller/Adminhtml/{Entity}/) are created during Step 4 file generation,"
echo "  not by this script — the entity name is not known at scaffold time."
echo ""
echo "Run scripts/verify-created.sh ${MODULE_PATH} after generation."
