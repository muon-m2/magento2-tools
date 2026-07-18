"""Pure, deterministic transforms for CVE-data curation. No I/O, no network.

Two of these guard silent failures the scanner cannot see:
  * normalize_range: version_in_range() needs an 'A - B' range; a bare "2.4.8" matches
    NOTHING (a dead entry — silent false negative).
  * is_prerelease/drop: parse_version() understands only -pN, so "2.4.9-alpha1" collapses
    to stable 2.4.9 — a pre-release range would falsely match the shipped release.
"""
import re

_PRERELEASE = re.compile(r'-(alpha|beta|rc)', re.IGNORECASE)


def normalize_range(r):
    """Bare single version -> self-range. version_in_range requires ' - '."""
    r = r.strip()
    if ' - ' in r:
        return r
    return f"{r} - {r}"


def is_prerelease(r):
    """True if any endpoint of the range carries a pre-release suffix parse_version drops."""
    return bool(_PRERELEASE.search(r))


def transform_entry(entry):
    """Return the entry with affected ranges cleaned, or None to exclude it.

    Excluded when nothing survives the pre-release drop. A B2B-only entry (all ranges
    tagged `component: b2b`) is KEPT — the resolver now resolves a B2B version, so a
    component:b2b range is matchable and dropping it would be dead data dressed as a
    curation decision.
    """
    affected = entry.get("affected") or []
    cleaned = []
    for a in affected:
        if not isinstance(a, dict):
            continue
        r = a.get("magento_version_range", "")
        if is_prerelease(r):
            continue
        cleaned.append({**a, "magento_version_range": normalize_range(r)})
    if not cleaned:
        return None
    out = dict(entry)
    out["affected"] = cleaned
    return out
