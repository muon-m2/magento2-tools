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


def _major(r):
    m = re.match(r'\s*(\d+)\.', r)
    return m.group(1) if m else None


def is_b2b_only(affected):
    """True if no affected range is a core (2.x) range — i.e. every range is B2B (1.x).

    The scanner resolves only a core magento_version, so a B2B-only advisory can never
    match and would be dead data dressed as coverage.
    """
    ranges = [a.get("magento_version_range", "") for a in affected
              if isinstance(a, dict)]
    if not ranges:
        return False
    return all(_major(r) not in (None, "2") for r in ranges)


def transform_entry(entry):
    """Return the entry with affected ranges cleaned, or None to exclude it.

    Excluded when B2B-only, or when nothing survives the pre-release drop.
    """
    affected = entry.get("affected") or []
    if is_b2b_only(affected):
        return None
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
