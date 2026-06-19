#!/usr/bin/env bash
# check-readiness.sh — read-only Marketplace/EQP readiness checks for a single module.
#
# Runs the marketplace-specific checks defined in references/eqp-checklist.md and outputs
# a JSON array of finding objects conforming to magento2-context/references/findings-schema.md.
#
# Inputs (env vars or positional):
#   TARGET_PATH   Path to the module root (required, or $1)
#   TARGET_MODULE Module name, e.g. "Acme_OrderExport" (default: derived from module.xml)
#
# Output:
#   JSON array of finding objects written to stdout.
#   Never installs anything, never modifies files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PATH="${TARGET_PATH:-${1:-}}"
: "${TARGET_PATH:?TARGET_PATH is required (pass as env var or \$1)}"

TARGET_MODULE="${TARGET_MODULE:-}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 0
fi

# ---------------------------------------------------------------------------
# Derive module name from etc/module.xml if not provided.
# ---------------------------------------------------------------------------
if [ -z "$TARGET_MODULE" ] && [ -f "${TARGET_PATH}/etc/module.xml" ]; then
    TARGET_MODULE="$(grep -oE 'name="[^"]+"' "${TARGET_PATH}/etc/module.xml" | head -1 | sed 's/name="//;s/"//' || true)"
fi
TARGET_MODULE="${TARGET_MODULE:-unknown_module}"

# ---------------------------------------------------------------------------
# Run all checks and emit findings via Python (keeps JSON generation clean).
# ---------------------------------------------------------------------------
TARGET_PATH="$TARGET_PATH" \
TARGET_MODULE="$TARGET_MODULE" \
python3 <<'PY'
import json
import os
import re
import sys

target_path = os.environ.get("TARGET_PATH", "").rstrip("/")
target_module = os.environ.get("TARGET_MODULE", "unknown_module")

findings = []
seq = 1


def finding(severity, category, title, file_path, line, recommendation,
            verification, subcategory=None, tags=None):
    global seq
    f = {
        "id": f"marketplace-{seq:04d}",
        "severity": severity,
        "category": category,
        "title": title,
        "evidence": [{"file": file_path, "line": line}],
        "recommendation": recommendation,
        "verification": verification,
        "tags": tags or ["eqp", "marketplace"],
    }
    if subcategory:
        f["subcategory"] = subcategory
    findings.append(f)
    seq += 1


# ---------------------------------------------------------------------------
# 1. composer.json checks
# ---------------------------------------------------------------------------
composer_path = os.path.join(target_path, "composer.json")
composer = {}
if not os.path.exists(composer_path):
    finding(
        "critical", "metadata",
        "composer.json missing",
        target_path, 1,
        "Create composer.json with type:magento2-module, version, license, require, and PSR-4 autoload.",
        "Run: composer validate --strict",
        subcategory="composer-missing",
        tags=["eqp", "marketplace", "blocker"],
    )
else:
    try:
        with open(composer_path, encoding="utf-8") as fh:
            composer = json.load(fh)
    except Exception as exc:
        finding(
            "critical", "metadata",
            f"composer.json is invalid JSON: {exc}",
            composer_path, 1,
            "Fix composer.json so it is valid JSON.",
            "Run: composer validate",
            subcategory="composer-invalid",
            tags=["eqp", "marketplace", "blocker"],
        )
        composer = {}

    if composer:
        # M2 — name
        name = composer.get("name", "")
        if not re.match(r'^[a-z0-9_-]+/[a-z0-9_-]*module[a-z0-9_-]*$', name):
            finding(
                "critical", "metadata",
                f"composer.json 'name' does not match vendor/module-* pattern (got: {name!r})",
                composer_path, 1,
                "Set 'name' to a lowercase hyphen-separated value like 'acme/module-order-export'.",
                "Run: composer validate; check that 'name' matches the Marketplace naming convention.",
                subcategory="name-pattern",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M3 — type
        if composer.get("type") != "magento2-module":
            finding(
                "critical", "metadata",
                f"composer.json 'type' must be 'magento2-module' (got: {composer.get('type')!r})",
                composer_path, 1,
                "Set 'type': 'magento2-module' in composer.json.",
                "Run: composer validate; confirm 'type' is correct.",
                subcategory="type-invalid",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M4 — version
        if not composer.get("version"):
            finding(
                "critical", "metadata",
                "composer.json 'version' field is missing",
                composer_path, 1,
                "Add a semver 'version' field (e.g. '1.0.0') to composer.json.",
                "Run: composer validate; confirm 'version' is present.",
                subcategory="version-missing",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M5 — license
        if not composer.get("license"):
            finding(
                "high", "metadata",
                "composer.json 'license' field is missing",
                composer_path, 1,
                "Add 'license' matching the LICENSE file (e.g. 'OSL-3.0' or 'proprietary').",
                "Run: composer validate; confirm 'license' is present.",
                subcategory="license-missing",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M6 — magento/framework in require
        require = composer.get("require", {})
        if "magento/framework" not in require:
            finding(
                "high", "metadata",
                "composer.json 'require' does not include 'magento/framework'",
                composer_path, 1,
                "Add 'magento/framework' with a compatible constraint to 'require'.",
                "Add the constraint and run: composer validate",
                subcategory="framework-missing",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M7 — PHP constraint in require
        if not any(k.startswith("php") for k in require):
            finding(
                "high", "metadata",
                "composer.json 'require' does not include a PHP version constraint",
                composer_path, 1,
                "Add a 'php' constraint (e.g. '>=8.1 <8.4') to 'require'.",
                "Add the constraint and run: composer validate",
                subcategory="php-constraint-missing",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M8 — PSR-4 autoload
        autoload = composer.get("autoload", {})
        if not autoload.get("psr-4"):
            finding(
                "high", "metadata",
                "composer.json 'autoload' does not configure PSR-4",
                composer_path, 1,
                "Add 'autoload': {'psr-4': {'Vendor\\\\Module\\\\': ''}} to composer.json.",
                "Run: composer validate; confirm autoload.psr-4 is present.",
                subcategory="autoload-missing",
                tags=["eqp", "marketplace", "blocker"],
            )

        # M9 — no dev/wildcard version constraints
        BAD_PATTERNS = re.compile(r'^(dev-|@dev|\*)|\*$')
        for pkg, constraint in require.items():
            if pkg in ("php", "php-64bit"):
                continue
            if BAD_PATTERNS.search(str(constraint)):
                finding(
                    "critical", "metadata",
                    f"Non-stable/wildcard version constraint in require: {pkg}: {constraint}",
                    composer_path, 1,
                    f"Replace '{constraint}' with a stable semver constraint for '{pkg}'.",
                    "Run: composer validate; EQP rejects non-stable constraints.",
                    subcategory="unstable-constraint",
                    tags=["eqp", "marketplace", "blocker", pkg],
                )

        # M10 — description
        if not composer.get("description"):
            finding(
                "medium", "metadata",
                "composer.json 'description' field is missing",
                composer_path, 1,
                "Add a concise 'description' for the Marketplace listing.",
                "Add 'description' and run: composer validate",
                subcategory="description-missing",
                tags=["eqp", "marketplace", "warning"],
            )

        # M11 — authors
        if not composer.get("authors"):
            finding(
                "medium", "metadata",
                "composer.json 'authors' field is missing",
                composer_path, 1,
                "Add 'authors' array with at least one entry (name + email).",
                "Add 'authors' and run: composer validate",
                subcategory="authors-missing",
                tags=["eqp", "marketplace", "warning"],
            )

# ---------------------------------------------------------------------------
# 2. LICENSE file
# ---------------------------------------------------------------------------
license_present = any(
    os.path.exists(os.path.join(target_path, f))
    for f in ("LICENSE", "LICENSE.txt", "LICENSE.md")
)
if not license_present:
    finding(
        "critical", "documentation",
        "LICENSE file is missing",
        target_path, 1,
        "Add a LICENSE file (e.g. LICENSE or LICENSE.txt) matching the license declared in composer.json.",
        "Confirm LICENSE file exists in the module root.",
        subcategory="license-file-missing",
        tags=["eqp", "marketplace", "blocker"],
    )

# ---------------------------------------------------------------------------
# 3. License headers in PHP files
# ---------------------------------------------------------------------------
php_files_missing_header = []
header_patterns = [
    re.compile(r'Copyright', re.IGNORECASE),
    re.compile(r'@license', re.IGNORECASE),
    re.compile(r'License', re.IGNORECASE),
]
php_checked = 0
for dirpath, dirnames, filenames in os.walk(target_path):
    # Skip vendor, generated, and Test directories for the header check.
    dirnames[:] = [d for d in dirnames if d not in ("vendor", "generated", "var", ".git", "node_modules")]
    for fname in filenames:
        if not fname.endswith(".php"):
            continue
        php_checked += 1
        fpath = os.path.join(dirpath, fname)
        try:
            with open(fpath, encoding="utf-8", errors="replace") as fh:
                head = fh.read(1024)
            if not any(p.search(head) for p in header_patterns):
                php_files_missing_header.append(fpath)
        except OSError:
            continue

if php_files_missing_header:
    # Report as a single finding with the first offending file as evidence;
    # list up to 5 in the description.
    sample = php_files_missing_header[:5]
    extras = len(php_files_missing_header) - len(sample)
    extra_note = f" (+{extras} more)" if extras else ""
    finding(
        "medium", "documentation",
        f"License/copyright header missing in {len(php_files_missing_header)} PHP file(s){extra_note}",
        php_files_missing_header[0], 1,
        "Add a license header block to all PHP files. Example:\n"
        " * Copyright © <Year> <Vendor>. All rights reserved.\n"
        " * See LICENSE.txt for license details.",
        "Re-run check-readiness.sh; all PHP files should have a license/copyright header.",
        subcategory="license-header-missing",
        tags=["eqp", "marketplace", "warning"] + sample,
    )

# ---------------------------------------------------------------------------
# 4. registration.php and etc/module.xml
# ---------------------------------------------------------------------------
reg_path = os.path.join(target_path, "registration.php")
mod_xml_path = os.path.join(target_path, "etc", "module.xml")

if not os.path.exists(reg_path):
    finding(
        "critical", "packaging",
        "registration.php is missing",
        target_path, 1,
        "Create registration.php to register the module with Magento's component registry.",
        "Check that registration.php exists in the module root.",
        subcategory="registration-missing",
        tags=["eqp", "marketplace", "blocker"],
    )

if not os.path.exists(mod_xml_path):
    finding(
        "critical", "packaging",
        "etc/module.xml is missing",
        target_path, 1,
        "Create etc/module.xml to declare the module name and sequence.",
        "Check that etc/module.xml exists.",
        subcategory="module-xml-missing",
        tags=["eqp", "marketplace", "blocker"],
    )

# Check name consistency between registration.php and etc/module.xml
if os.path.exists(reg_path) and os.path.exists(mod_xml_path):
    try:
        reg_content = open(reg_path, encoding="utf-8", errors="replace").read()
        xml_content = open(mod_xml_path, encoding="utf-8", errors="replace").read()

        # Extract module name from registration.php: ComponentRegistrar::register(..., 'Vendor_Module', ...)
        reg_match = re.search(r"ComponentRegistrar::register\s*\([^,]+,\s*['\"]([A-Za-z0-9_]+)['\"]", reg_content)
        # Extract module name from module.xml: <module name="Vendor_Module"/>
        xml_match = re.search(r'<module\s+name="([A-Za-z0-9_]+)"', xml_content)

        if reg_match and xml_match:
            reg_name = reg_match.group(1)
            xml_name = xml_match.group(1)
            if reg_name != xml_name:
                finding(
                    "critical", "packaging",
                    f"Module name mismatch: registration.php={reg_name!r}, etc/module.xml={xml_name!r}",
                    reg_path, 1,
                    "Ensure the module name in registration.php matches etc/module.xml.",
                    "Fix the mismatch and re-run bin/magento setup:upgrade to verify.",
                    subcategory="name-mismatch",
                    tags=["eqp", "marketplace", "blocker"],
                )
    except OSError:
        pass

# ---------------------------------------------------------------------------
# 5. MFTF tests
# ---------------------------------------------------------------------------
mftf_dir = os.path.join(target_path, "Test", "Mftf")
if not os.path.isdir(mftf_dir):
    finding(
        "medium", "testing",
        "MFTF functional tests not found under Test/Mftf/",
        target_path, 1,
        "Add MFTF functional tests under Test/Mftf/. Marketplace evaluates functional test coverage.",
        "Confirm Test/Mftf/ exists and contains at least one ActionGroup or Test XML file.",
        subcategory="mftf-missing",
        tags=["eqp", "marketplace", "warning"],
    )

# ---------------------------------------------------------------------------
# 6. README / user documentation
# ---------------------------------------------------------------------------
readme_present = any(
    os.path.exists(os.path.join(target_path, f))
    for f in ("README.md", "README.rst", "README.txt", "README")
)
if not readme_present:
    finding(
        "medium", "documentation",
        "README file is missing",
        target_path, 1,
        "Add a README.md with at least an installation and configuration/usage section.",
        "Confirm README.md exists in the module root.",
        subcategory="readme-missing",
        tags=["eqp", "marketplace", "warning"],
    )

# ---------------------------------------------------------------------------
# 7. Packaging hygiene — dev artifacts
# ---------------------------------------------------------------------------
DEV_ARTIFACTS = [
    ".DS_Store", "Thumbs.db", ".env", ".env.local",
    "node_modules", ".vagrant", "nbproject",
]
found_artifacts = []
for artifact in DEV_ARTIFACTS:
    artifact_path = os.path.join(target_path, artifact)
    if os.path.exists(artifact_path):
        found_artifacts.append(artifact_path)

if found_artifacts:
    finding(
        "medium", "packaging",
        f"Dev artifacts found in module tree: {', '.join(os.path.basename(a) for a in found_artifacts)}",
        found_artifacts[0], 1,
        "Remove dev artifacts from the module directory and add them to .gitignore and composer.json 'archive.exclude'.",
        "Confirm dev artifacts are removed or excluded from the package.",
        subcategory="dev-artifacts",
        tags=["eqp", "marketplace", "warning"] + [os.path.basename(a) for a in found_artifacts],
    )

# ---------------------------------------------------------------------------
# 8. .gitignore
# ---------------------------------------------------------------------------
gitignore_path = os.path.join(target_path, ".gitignore")
if not os.path.exists(gitignore_path):
    finding(
        "low", "packaging",
        ".gitignore file is missing",
        target_path, 1,
        "Add a .gitignore to exclude dev artifacts (node_modules/, .DS_Store, *.log, etc.).",
        "Confirm .gitignore exists.",
        subcategory="gitignore-missing",
        tags=["eqp", "marketplace", "info"],
    )

print(json.dumps(findings, indent=2))
PY
