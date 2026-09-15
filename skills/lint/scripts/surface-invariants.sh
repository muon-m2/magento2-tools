#!/usr/bin/env bash
# surface-invariants.sh — cross-file completeness checks over one Magento 2 module.
#
# WHY THIS EXISTS
# Every rule here was derived from a real defect where a generator emitted N-1 of the N files a
# surface needs, and every existing gate passed: XSD validation, `setup:di:compile`, PHPUnit
# (because the tests mocked the very collaborator whose wiring was missing), phpcs and phpstan.
# The failure only appeared at runtime, often silently. See references/surface-invariants.md for
# the rule catalogue and the bug report behind each one.
#
# These are not style rules. Each asserts a relationship BETWEEN files that no single-file
# linter can see: a topic declared here must have a publisher there; a class registered here
# must implement an interface over there.
#
# Inputs (env vars):
#   TARGET_PATH    module directory to check (required), e.g. src/app/code/Acme/Widget
#   SCAN_ROOT      app/code root, for sibling-module cross-references (default: parent of the
#                  module's Vendor dir)
#   MAGENTO_ROOT   holds vendor/ — the ACL reference set (default: auto-detected from cwd)
#   FINDINGS_FILE  output path for the JSON findings array (default: a new temp file the caller
#                  owns; path echoed)
#   DATE           finding-id date component (default: today UTC)
#   ID_PREFIX      finding-id prefix (default: quality)
#   SEQ_START      first sequence number for finding ids (default: 900, so the pack's ids do
#                  not collide with the tool-driven scanners' ids in the same document)
#
# Output:
#   JSON array of findings (findings-schema.md shape, category "surface") at FINDINGS_FILE.
#   Prints FINDINGS_FILE to stdout.
#
# Degradation is LOUD, never silent: an unparseable file, or an absent ACL reference set, is
# written to stderr — build-findings.sh turns this scanner's stderr into the document's
# `scanner_errors`, which is how "checked and clean" stays distinguishable from "not checked".
# A check that cannot be decided is skipped and reported; it never reports a pass.
#
# Exit codes: 0 always when the scan itself ran (findings are data, not an error); 2 = bad usage.

set -uo pipefail

: "${TARGET_PATH:?TARGET_PATH is required}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "surface-invariants: python3 required — surface completeness was NOT checked" >&2
    exit 2
fi

# The default output is created OUTSIDE any directory this script cleans up, because its path is
# printed for the caller to read after this script exits. It used to live in a temp dir whose EXIT
# trap deleted it first.
if [ -z "${FINDINGS_FILE:-}" ]; then
    FINDINGS_FILE="$(mktemp "${TMPDIR:-/tmp}/surface-invariants.XXXXXX")"
fi
mkdir -p "$(dirname "$FINDINGS_FILE")"

TARGET_PATH="$TARGET_PATH" \
SCAN_ROOT="${SCAN_ROOT:-}" \
MAGENTO_ROOT="${MAGENTO_ROOT:-}" \
DATE="${DATE:-$(date -u +%Y-%m-%d)}" \
ID_PREFIX="${ID_PREFIX:-quality}" \
SEQ_START="${SEQ_START:-900}" \
python3 - > "$FINDINGS_FILE" <<'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

target = os.environ['TARGET_PATH'].rstrip('/')
scan_root = os.environ.get('SCAN_ROOT') or os.path.dirname(os.path.dirname(target))
def detect_magento_root():
    """Find the tree holding vendor/. Documented behaviour, so it must actually happen: without
    it a standalone run reports SI-09 as 'not checked' even when vendor/ is right there."""
    env = os.environ.get('MAGENTO_ROOT') or ''
    if env:
        return env
    for cand in ('src', '.'):
        if os.path.isdir(os.path.join(cand, 'vendor', 'magento')) or \
                os.path.isdir(os.path.join(cand, 'vendor')):
            return cand
    # Walk up from the module: app/code/V/M and vendor/<v>/module-x both sit under the root.
    here = os.path.abspath(target)
    for _ in range(8):
        parent = os.path.dirname(here)
        if parent == here:
            break
        if os.path.isdir(os.path.join(parent, 'vendor', 'magento')):
            return parent
        here = parent
    return ''


magento_root = detect_magento_root()
date = os.environ['DATE']
id_prefix = os.environ['ID_PREFIX']
seq = int(os.environ['SEQ_START'])

findings = []


def warn(msg):
    print('surface-invariants: %s' % msg, file=sys.stderr)


def add(rule, severity, title, description, evidence, recommendation, verification):
    """evidence: list of (path, line) — paths are stored module-relative for readability."""
    global seq
    ev = []
    for path, line in evidence:
        rel = os.path.relpath(path, target) if os.path.isabs(path) or path.startswith(target) \
            else path
        ev.append({'file': rel, 'line': max(1, int(line))})
    findings.append({
        'id': '%s-%s-%03d' % (id_prefix, date, seq),
        'severity': severity,
        'category': 'surface',
        'subcategory': rule,
        'confidence': 'confirmed',
        'title': title,
        'description': description,
        'evidence': ev,
        'recommendation': recommendation,
        'verification': verification,
        'tags': ['surface-completeness', 'magento-wiring'],
    })
    seq += 1


# --------------------------------------------------------------------------- helpers
def mod_path(*parts):
    return os.path.join(target, *parts)


def read(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError as exc:
        warn('could not read %s (%s)' % (path, exc.__class__.__name__))
        return ''


def parse_xml(path):
    """Returns an ElementTree root, or None. A malformed file is NAMED on stderr — silently
    treating it as absent would turn a broken file into a clean bill of health."""
    if not os.path.isfile(path):
        return None
    try:
        return ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        warn('%s is not parseable (%s) — checks depending on it were skipped'
             % (os.path.relpath(path, target) if path.startswith(target) else path, exc))
        return None


def line_of(path, *needles):
    """1-based line of the first needle that appears in the file; 1 when none match."""
    text = read(path)
    for needle in needles:
        if not needle:
            continue
        idx = text.find(needle)
        if idx != -1:
            return text.count('\n', 0, idx) + 1
    return 1


def walk_files(root, suffixes):
    """Skips build/dependency dirs and the module's OWN test root only. Excluding every
    directory named `Test` would also hide Controller/Adminhtml/Test/SendSms.php — a real
    action class — and make SI-11 report it as unresolvable."""
    out = []
    test_root = os.path.join(target, 'Test')
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames
                       if d not in ('vendor', 'generated', 'var', 'node_modules')
                       and os.path.join(dirpath, d) != test_root]
        for name in filenames:
            if name.endswith(suffixes):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


php_files = walk_files(target, ('.php',))
module_name = None
_mod_root = parse_xml(mod_path('etc', 'module.xml'))
if _mod_root is not None:
    for el in _mod_root.iter('module'):
        module_name = el.get('name')
        break
if not module_name:
    # Fall back to the path shape: .../Vendor/Module
    parts = target.split(os.sep)
    if len(parts) >= 2:
        module_name = '%s_%s' % (parts[-2], parts[-1])


def php_class_of(path):
    """Fully-qualified class name declared in a PHP file, or None."""
    text = read(path)
    ns = re.search(r'^\s*namespace\s+([^;]+);', text, re.M)
    cls = re.search(r'^\s*(?:final\s+|abstract\s+)*class\s+(\w+)', text, re.M)
    if not ns or not cls:
        return None
    return '%s\\%s' % (ns.group(1).strip(), cls.group(1))


class_index = {}
for _p in php_files:
    _c = php_class_of(_p)
    if _c:
        class_index[_c] = _p


def resolve_use(text, short):
    """Map a short class name back to its FQN via the file's use statements."""
    m = re.search(r'^\s*use\s+([^;]*\\%s)\s*;' % re.escape(short), text, re.M)
    return m.group(1).strip() if m else None


# Verbatim from Magento\Framework\App\Router\ActionList::$reservedWords (2.4.8). The router
# appends 'action' to a path segment that collides with one of these, which is why the class
# behind .../store/switch is SwitchAction.
ROUTER_RESERVED_WORDS = {
    'abstract', 'and', 'array', 'as', 'break', 'callable', 'case', 'catch', 'class', 'clone',
    'const', 'continue', 'declare', 'default', 'die', 'do', 'echo', 'else', 'elseif', 'empty',
    'enddeclare', 'endfor', 'endforeach', 'endif', 'endswitch', 'endwhile', 'eval', 'exit',
    'extends', 'final', 'finally', 'fn', 'for', 'foreach', 'function', 'global', 'goto', 'if',
    'implements', 'include', 'instanceof', 'insteadof', 'interface', 'isset', 'list', 'match',
    'namespace', 'new', 'or', 'print', 'private', 'protected', 'public', 'require', 'return',
    'static', 'switch', 'throw', 'trait', 'try', 'unset', 'use', 'var', 'void', 'while', 'xor',
    'yield',
}


def kebab(name):
    return re.sub(r'(?<!^)(?=[A-Z])', '-', name).lower()


def resolve_class_file(fqn):
    """Locate the file declaring a class: this module first, then vendor/magento by deriving the
    package path from the namespace (Magento\\Framework\\X → vendor/magento/framework/X.php;
    Magento\\Catalog\\X → vendor/magento/module-catalog/X.php). Returns None when unresolvable —
    a third-party vendor class, typically."""
    fqn = fqn.lstrip('\\')
    if fqn in class_index:
        return class_index[fqn]
    parts = fqn.split('\\')
    if len(parts) < 3 or parts[0] != 'Magento' or not magento_root:
        return None
    tail = os.path.join(*parts[2:]) + '.php'
    if parts[1] == 'Framework':
        cand = os.path.join(magento_root, 'vendor', 'magento', 'framework', tail)
    else:
        cand = os.path.join(magento_root, 'vendor', 'magento',
                            'module-' + kebab(parts[1]), tail)
    return cand if os.path.isfile(cand) else None


# Vanilla collection bases that definitively do NOT provide the SearchResultInterface bridge.
# Reaching one of these ends the walk with a verdict instead of an "unknown".
VANILLA_COLLECTION_BASES = {
    'Magento\\Framework\\Model\\ResourceModel\\Db\\Collection\\AbstractCollection',
    'Magento\\Eav\\Model\\Entity\\Collection\\AbstractCollection',
    'Magento\\Framework\\Data\\Collection\\AbstractDb',
    'Magento\\Framework\\Data\\Collection',
}


def provides_bridge(fqn, depth=0):
    """True  — this class or an ancestor provides the SearchResultInterface bridge.
    False — the chain terminates in a known vanilla collection base without it.
    None  — undecidable (an ancestor could not be resolved); the caller must skip, not guess."""
    if depth > 8:
        return None
    path = resolve_class_file(fqn)
    if not path:
        return None
    text = read(path)
    if ('SearchResultInterface' in text
            or re.search(r'\bextends\s+SearchResult\b', text) is not None
            or SEARCH_RESULT in text
            or all(('function %s' % m) in text for m in BRIDGE_METHODS)):
        return True
    m = re.search(r'^\s*(?:final\s+|abstract\s+)*class\s+\w+\s+extends\s+([\w\\]+)', text, re.M)
    if not m:
        return False  # a root class with no bridge
    parent_short = m.group(1)
    parent = parent_short if '\\' in parent_short else (resolve_use(text, parent_short)
                                                        or parent_short)
    parent = parent.lstrip('\\')
    if parent in VANILLA_COLLECTION_BASES:
        return False
    return provides_bridge(parent, depth + 1)


# =========================================================================== SI-01/02/03
# Message-queue surface: a topic needs a publisher AND a topology binding, and a consumer's
# queue must be a destination some binding actually creates. Origin: a module shipped
# communication + topology + consumer but no queue_publisher.xml; unit tests mocked
# PublisherInterface, so topic→publisher resolution was never exercised (it throws at runtime).
comm = parse_xml(mod_path('etc', 'communication.xml'))
if comm is not None:
    topics = [t.get('name') for t in comm.iter('topic') if t.get('name')]

    # A topic's publisher and topology binding may legitimately live in a SIBLING module (a
    # module declares the contract, an integration module wires the transport), so the index is
    # built repo-wide. Scoping it to this module alone would fire on a correct split.
    def queue_xml_files(basename):
        out = []
        for root_dir in {scan_root, target}:
            if not root_dir or not os.path.isdir(root_dir):
                continue
            for dirpath, dirnames, filenames in os.walk(root_dir):
                dirnames[:] = [d for d in dirnames
                               if d not in ('vendor', 'generated', 'var', 'node_modules')]
                if basename in filenames and os.path.basename(dirpath) == 'etc':
                    out.append(os.path.join(dirpath, basename))
        return sorted(set(out))

    published = set()
    for p in queue_xml_files('queue_publisher.xml'):
        r = parse_xml(p)
        if r is not None:
            published |= {el.get('topic') for el in r.iter('publisher') if el.get('topic')}

    bindings = []
    for p in queue_xml_files('queue_topology.xml'):
        r = parse_xml(p)
        if r is None:
            continue
        for b in r.iter('binding'):
            bindings.append((b.get('topic'), b.get('destination'), b.get('destinationType')))
    bound_topics = {t for t, _d, _dt in bindings if t}
    queues = {d for _t, d, dt in bindings if d and (dt or 'queue') == 'queue'}

    for topic in topics:
        ln = line_of(mod_path('etc', 'communication.xml'), 'name="%s"' % topic)
        if topic not in published:
            add('SI-01', 'high',
                'Queue topic "%s" has no publisher declaration' % topic,
                'etc/communication.xml declares the topic but no queue_publisher.xml entry '
                'publishes it. PublisherInterface resolves the topic to a connection at '
                'publish time and throws when the topic is unmapped, so the first publish in '
                'production fails. Unit tests that mock PublisherInterface never exercise this '
                'resolution, which is why the gap survives a green test suite.',
                [(mod_path('etc', 'communication.xml'), ln)],
                'Add etc/queue_publisher.xml with <publisher topic="%s"> and a <connection '
                'name="db|amqp" exchange="magento-db|magento"/> child.' % topic,
                'bin/magento setup:upgrade then publish once: the topic must resolve without '
                'a "Publisher for topic %s is not configured" error.' % topic)
        if topic not in bound_topics:
            add('SI-02', 'high',
                'Queue topic "%s" has no topology binding' % topic,
                'etc/queue_topology.xml exists but binds no exchange to this topic, so nothing '
                'routes a published message to a queue: the publish succeeds and the payload is '
                'silently dropped.',
                [(mod_path('etc', 'communication.xml'), ln)],
                'Add a <binding topic="%s" destinationType="queue" destination="..."/> under '
                'the exchange this topic publishes to.' % topic,
                'bin/magento queue:consumers:list and confirm the consumer drains a test '
                'message end to end.')

    cons_path = mod_path('etc', 'queue_consumer.xml')
    cons_root = parse_xml(cons_path)
    if cons_root is not None:
        for c in cons_root.iter('consumer'):
            q = c.get('queue')
            if q and q not in queues:
                add('SI-03', 'high',
                    'Consumer "%s" listens on queue "%s", which no topology binding creates'
                    % (c.get('name'), q),
                    'The consumer starts and blocks on a queue that nothing routes messages '
                    'to. It looks healthy in queue:consumers:list and processes nothing.',
                    [(cons_path, line_of(cons_path, 'queue="%s"' % q))],
                    'Either add a topology binding whose destination is "%s", or point the '
                    'consumer at an existing bound queue.' % q,
                    'Publish one message and confirm the consumer processes it.')

# =========================================================================== SI-04/05
# Custom cache type: a TagScope subclass must be registered in cache.xml, and consumers must
# type it as Cache\FrontendInterface. Origins: a cache class with no cache.xml/di.xml wiring
# whose constructor was never exercised because tests mocked its callers; and a service typed
# against App\CacheInterface while di.xml wired the concrete TagScope subclass → TypeError.
APP_CACHE = 'Magento\\Framework\\App\\CacheInterface'
tagscope_classes = {}
for path in php_files:
    text = read(path)
    if not re.search(r'\bextends\s+TagScope\b', text) and 'Decorator\\TagScope' not in text:
        continue
    cls = php_class_of(path)
    if not cls:
        continue
    ident = None
    m = re.search(r'TYPE_IDENTIFIER\s*=\s*[\'"]([^\'"]+)[\'"]', text)
    if m:
        ident = m.group(1)
    tagscope_classes[cls] = (path, ident)

if tagscope_classes:
    cache_path = mod_path('etc', 'cache.xml')
    cache_root = parse_xml(cache_path)
    registered = {t.get('name') for t in cache_root.iter('type')} if cache_root is not None else set()
    for cls, (path, ident) in sorted(tagscope_classes.items()):
        if ident is None:
            warn('%s extends TagScope but declares no TYPE_IDENTIFIER constant — SI-04 skipped '
                 'for it' % os.path.relpath(path, target))
            continue
        if ident not in registered:
            add('SI-04', 'high',
                'Cache type "%s" is not registered in cache.xml' % ident,
                '%s extends TagScope and asks FrontendPool for the cache frontend "%s", but no '
                'etc/cache.xml declares that type. FrontendPool throws '
                '"Cache frontend \'%s\' is not recognized" the first time the class is '
                'constructed through real DI — which no test reaches while callers mock this '
                'collaborator. The cache type is also absent from cache:status, so it can '
                'never be flushed or disabled by an operator.' % (cls, ident, ident),
                [(path, line_of(path, 'TYPE_IDENTIFIER'))],
                'Add etc/cache.xml with <type name="%s" translate="label,description" '
                'instance="%s"><label>…</label><description>…</description></type>.'
                % (ident, cls),
                'bin/magento cache:status lists "%s"; construct the class through DI (an '
                'integration test, not a mock) without a FrontendPool exception.' % ident)

    # SI-05 — di.xml maps an argument to a TagScope subclass, but the receiving constructor
    # parameter is typed App\CacheInterface, which TagScope does not implement.
    for di_rel in ('etc/di.xml', 'etc/adminhtml/di.xml', 'etc/frontend/di.xml',
                   'etc/webapi_rest/di.xml', 'etc/graphql/di.xml', 'etc/crontab/di.xml'):
        di_path = mod_path(*di_rel.split('/'))
        di_root = parse_xml(di_path)
        if di_root is None:
            continue
        for type_el in list(di_root.iter('type')) + list(di_root.iter('virtualType')):
            consumer_cls = type_el.get('name')
            for arg in type_el.iter('argument'):
                value = (arg.text or '').strip()
                if value not in tagscope_classes:
                    continue
                arg_name = arg.get('name')
                if not arg_name:
                    # Nameless <argument> (invalid per the DI XSD). We cannot know which
                    # parameter it feeds, and guessing blamed the first typed one.
                    warn('%s has an <argument> with no name= feeding %s — SI-05 cannot be '
                         'decided for it' % (di_rel, consumer_cls))
                    continue
                target_file = class_index.get(consumer_cls)
                if not target_file:
                    continue  # class lives outside this module — cannot judge its signature
                ctext = read(target_file)
                ctor = re.search(r'function\s+__construct\s*\((.*?)\)\s*\{', ctext, re.S)
                if not ctor:
                    continue
                # Matches a promoted property too — `private CacheInterface $cache` — because
                # the visibility modifier precedes the type, which is all this pattern needs.
                pm = re.search(r'([\w\\]+)\s+\$%s\b' % re.escape(arg_name), ctor.group(1))
                if not pm:
                    continue
                hint = pm.group(1).lstrip('\\')
                fq = hint if '\\' in hint else (resolve_use(ctext, hint) or hint)
                if fq.lstrip('\\') == APP_CACHE:
                    add('SI-05', 'high',
                        'Custom cache type injected into a parameter typed App\\CacheInterface',
                        '%s wires the cache type %s into $%s of %s, but that parameter is typed '
                        '%s. A TagScope subclass implements Magento\\Framework\\Cache\\'
                        'FrontendInterface and NOT App\\CacheInterface, so object creation dies '
                        'with a TypeError the first time DI builds this class. The two '
                        'interfaces also differ in shape (load/save signatures), so switching '
                        'the type hint may require adjusting the call sites.'
                        % (di_rel, value, arg_name, consumer_cls, APP_CACHE),
                        [(target_file, line_of(target_file, '$%s' % arg_name, '__construct')),
                         (di_path, line_of(di_path, value))],
                        'Type the parameter as \\Magento\\Framework\\Cache\\FrontendInterface '
                        '(the interface TagScope implements), or inject the pool and resolve '
                        'the frontend explicitly.',
                        'bin/magento setup:di:compile then construct %s through DI — no '
                        'TypeError.' % consumer_cls)

# =========================================================================== SI-06 / SI-10
# UI-component grid data sources. Origins: a generated "vanilla" entity collection registered
# as a grid data source (the generic DataProvider calls SearchResultInterface methods on it →
# TypeError / foreach on null); and the same registration placed in an area-specific di.xml,
# where `collections` array items from different modules do not merge as they do in global
# etc/di.xml, so only one module's grids survive.
COLLECTION_FACTORY = 'Magento\\Framework\\View\\Element\\UiComponent\\DataProvider\\CollectionFactory'
SEARCH_RESULT = 'Magento\\Framework\\View\\Element\\UiComponent\\DataProvider\\SearchResult'
BRIDGE_METHODS = ('getAggregations', 'setAggregations', 'getSearchCriteria',
                  'setSearchCriteria', 'getTotalCount', 'setTotalCount')

for di_rel in ('etc/di.xml', 'etc/adminhtml/di.xml', 'etc/frontend/di.xml'):
    di_path = mod_path(*di_rel.split('/'))
    di_root = parse_xml(di_path)
    if di_root is None:
        continue
    for type_el in di_root.iter('type'):
        if type_el.get('name') != COLLECTION_FACTORY:
            continue
        # Only the `collections` argument registers grid data sources. The <type> block may
        # exist for unrelated arguments, and other arrays under it can hold class-like strings,
        # so neither rule may key off the block alone.
        collections_arg = None
        for arg in type_el.iter('argument'):
            if arg.get('name') == 'collections':
                collections_arg = arg
                break
        if collections_arg is None:
            continue
        area_specific = di_rel != 'etc/di.xml'
        if area_specific:
            add('SI-10', 'high',
                'Grid collection registration is in an area-specific di.xml',
                'The `collections` argument of %s is declared in %s. Items in that array merge '
                'across modules only in the GLOBAL etc/di.xml; in an area file each module\'s '
                'array replaces rather than unions, so registering here silently drops other '
                'modules\' grid data sources — including core grids such as Customers. The '
                'symptom appears in an unrelated module, which makes it expensive to trace.'
                % (COLLECTION_FACTORY, di_rel),
                [(di_path, line_of(di_path, COLLECTION_FACTORY))],
                'Move the <type name="%s"> block to etc/di.xml.' % COLLECTION_FACTORY,
                'Open this module\'s grid AND the Customers grid in the admin — both must '
                'render rows.')
        for item in collections_arg.iter('item'):
            cls = (item.text or '').strip()
            if not cls:
                continue
            coll_file = class_index.get(cls)
            if not coll_file:
                continue  # defined elsewhere (virtualType or another module) — cannot judge
            verdict = provides_bridge(cls)
            if verdict is None:
                warn('cannot resolve the base-class chain of %s — SI-06 skipped for grid data '
                     'source "%s"' % (cls, item.get('name')))
                continue
            if not verdict:
                add('SI-06', 'high',
                    'Grid data source "%s" is not a SearchResult collection' % item.get('name'),
                    '%s is registered as a UI-component grid data source, but it is a plain '
                    'entity collection: it does not extend %s, implement SearchResultInterface, '
                    'or provide the bridge methods (%s). The generic DataProvider calls those '
                    'methods on whatever it is handed, so the grid dies at render time with a '
                    'TypeError or a foreach over null. XSD validation and di:compile both pass, '
                    'and unit tests that build the collection directly never go through the '
                    'DataProvider.'
                    % (cls, SEARCH_RESULT, ', '.join(BRIDGE_METHODS)),
                    [(coll_file, line_of(coll_file, 'class '))],
                    'Register a Grid/Collection that extends %s (the usual pattern: '
                    'Model/ResourceModel/{Entity}/Grid/Collection.php), or point the listing at '
                    'a custom DataProvider that builds the item array itself.' % SEARCH_RESULT,
                    'Open the grid in the admin: rows render, filtering and paging work.')

# =========================================================================== SI-07 / SI-08
# UI-component form XML. Origins: a generated form whose root <argument name="data"> dropped
# the standard `template` item — XSD and di:compile pass, and the admin form renders as an
# endless spinner; and a dynamicRows declaring both name="x" and <dataScope>x</dataScope>,
# which double-appends the scope so the field binds to x.x and saves nothing.
for form_path in walk_files(mod_path('view'), ('.xml',)):
    if os.sep + 'ui_component' + os.sep not in form_path:
        continue
    root = parse_xml(form_path)
    if root is None or not root.tag.endswith('form'):
        continue
    data_arg = None
    for arg in root.findall('argument'):
        if arg.get('name') == 'data':
            data_arg = arg
            break
    if data_arg is not None:
        items = {i.get('name') for i in data_arg.iter('item')}
        if 'template' not in items:
            add('SI-07', 'high',
                'Form UI component declares no `template` item',
                'The root <argument name="data"> of this form omits '
                '<item name="template" xsi:type="string">templates/form/collapsible</item>, '
                'which every core form declares. XSD validation and setup:di:compile both pass '
                'without it; the failure is visual only — the admin form renders as a '
                'never-resolving loader, so nothing but opening the page catches it.',
                [(form_path, line_of(form_path, '<argument name="data"'))],
                'Add <item name="template" xsi:type="string">templates/form/collapsible</item> '
                'to the root data argument (alongside js_config).',
                'Open the form in the admin: fields render and the loader clears.')
    for el in root.iter():
        if not el.tag.endswith('dynamicRows'):
            continue
        name = el.get('name')
        if not name:
            continue
        for ds in el.iter('dataScope'):
            if (ds.text or '').strip() == name:
                add('SI-08', 'medium',
                    'dynamicRows "%s" repeats its own name as dataScope' % name,
                    'The dynamicRows binding already appends the component name to the parent '
                    'scope, so declaring <dataScope>%s</dataScope> on a component named "%s" '
                    'resolves to "%s.%s". The grid renders but binds to a path the data '
                    'provider never fills, so existing rows do not load and edits do not save.'
                    % (name, name, name, name),
                    [(form_path, line_of(form_path, '<dataScope>%s</dataScope>' % name))],
                    'Drop the <dataScope> element (the name already provides it), or set it to '
                    'the actual field key when it differs from the component name.',
                    'Edit an entity with existing rows: they load, and a change persists after '
                    'save.')

# =========================================================================== SI-09
# ACL tree. Origin: a generated acl.xml re-declared the core resource Magento_Config::config
# under the wrong parent (the Magento_Backend::stores_settings level was missing). Acl\Builder
# merges every module's acl.xml into one tree; the same id under a different parent throws
# "Resource id '…' already exists in the ACL" from Session::processLogin() — nobody can log
# into the admin, while the storefront stays perfectly healthy.
acl_path = mod_path('etc', 'acl.xml')
acl_root = parse_xml(acl_path)
if acl_root is not None:
    def acl_pairs(root):
        """{resource id: parent id or None} for one acl.xml."""
        out = {}

        def walk(node, parent):
            for child in node:
                if not child.tag.endswith('resource'):
                    walk(child, parent)
                    continue
                rid = child.get('id')
                if rid:
                    out.setdefault(rid, parent)
                    walk(child, rid)
                else:
                    walk(child, parent)
        walk(root, None)
        return out

    mine = acl_pairs(acl_root)

    import glob as _glob

    reference = {}
    vendor_dir = os.path.join(magento_root, 'vendor', 'magento') if magento_root else ''
    ref_files = []
    if magento_root:
        # Any composer package may own a resource id, not only vendor/magento. Globbed rather
        # than walked: os.walk over vendor/ costs tens of thousands of stats for no more
        # coverage than the canonical <package>/etc/acl.xml location.
        ref_files += _glob.glob(os.path.join(magento_root, 'vendor', '*', '*', 'etc', 'acl.xml'))
    if scan_root and os.path.isdir(scan_root):
        ref_files += _glob.glob(os.path.join(scan_root, '*', '*', 'etc', 'acl.xml'))
        ref_files += _glob.glob(os.path.join(scan_root, '*', '*', 'etc', '*', 'acl.xml'))
    ref_files = [p for p in sorted(set(ref_files))
                 if os.path.abspath(p) != os.path.abspath(acl_path)]
    def declaring_module(acl_file):
        """Module that ships this acl.xml, from its sibling etc/module.xml."""
        mx = parse_xml(os.path.join(os.path.dirname(acl_file), 'module.xml'))
        if mx is None:
            # An area-specific acl.xml lives at etc/<area>/acl.xml, so its module.xml is one
            # level up — at etc/module.xml, NOT etc/etc/module.xml.
            mx = parse_xml(os.path.join(os.path.dirname(os.path.dirname(acl_file)),
                                        'module.xml'))
        if mx is None:
            return None
        for el in mx.iter('module'):
            return el.get('name')
        return None

    # A resource id is authoritative ONLY from the module that owns its prefix. Accepting any
    # module's declaration would let one module's MISTAKE become the reference the next module
    # is judged against — which made the correct chain look like the mismatch.
    known_ids = set()
    for p in ref_files:
        r = parse_xml(p)
        if r is None:
            continue
        pairs = acl_pairs(r)
        known_ids |= set(pairs)
        owner = declaring_module(p)
        if not owner:
            # Ownership undeterminable (no sibling module.xml): its ids still COUNT AS EXISTING
            # for the unknown-parent check, they just cannot define the canonical parent.
            continue
        for rid, parent in pairs.items():
            if parent is not None and rid.startswith(owner + '::'):
                reference.setdefault(rid, (parent, p))

    if not vendor_dir or not os.path.isdir(vendor_dir):
        warn('no vendor/magento tree under %r — the core ACL id reference set is unavailable, '
             'so SI-09 (ACL parent-chain mismatch, an admin-lockout class) was NOT checked'
             % (magento_root or os.getcwd()))
    else:
        own_prefix = (module_name or '') + '::'
        for rid, parent in sorted(mine.items()):
            if not parent or rid.startswith(own_prefix):
                continue  # our own ids are ours to place
            if rid not in reference:
                continue  # unknown foreign id — reported by SI-09b below
            ref_parent, ref_file = reference[rid]
            if ref_parent != parent:
                add('SI-09', 'critical',
                    'ACL resource "%s" is re-declared under a different parent' % rid,
                    'This module places the foreign resource "%s" under "%s", but its owning '
                    'module declares it under "%s" (%s). Acl\\Builder merges every acl.xml into '
                    'one tree and adds each resource beneath its declared parent; the same id '
                    'arriving under two parents raises "Resource id \'%s\' already exists in '
                    'the ACL". That exception is thrown from Backend\\Model\\Auth\\Session::'
                    'processLogin(), so NO ONE can log into the admin — while the storefront is '
                    'unaffected, which is why a storefront smoke test and an HTTP 302 on '
                    '/admin both still look green.'
                    % (rid, parent, ref_parent,
                       os.path.basename(os.path.dirname(os.path.dirname(ref_file))), rid),
                    [(acl_path, line_of(acl_path, 'id="%s"' % rid))],
                    'Re-declare the full canonical chain down to "%s" (insert the missing "%s" '
                    'level) so the id keeps its owner\'s parent, then nest your own '
                    '%s… resources beneath it.' % (rid, ref_parent, own_prefix),
                    'Log into the admin with real credentials — the dashboard must render. '
                    'Also check var/report/ and var/log/system.log stay clean afterwards.')
        for rid, parent in sorted(mine.items()):
            if not parent or rid.startswith(own_prefix) or rid in known_ids:
                continue
            if rid == 'Magento_Backend::admin':
                continue
            add('SI-12', 'high',
                'ACL parent resource "%s" is declared by no module' % rid,
                'This acl.xml nests resources under "%s", which no enabled module (and no '
                'vendor/magento module) declares. The subtree attaches to nothing, so the '
                'resources never appear in Roles → Resources and any <resource> reference to '
                'them in system.xml or a controller\'s ADMIN_RESOURCE silently denies access.'
                % rid,
                [(acl_path, line_of(acl_path, 'id="%s"' % rid))],
                'Correct the id to an existing resource (check the owning module\'s '
                'etc/acl.xml), or declare the intermediate levels this module actually needs.',
                'System → Permissions → User Roles → Role Resources: the subtree appears at '
                'the expected place in the tree.')

# =========================================================================== SI-11
# Route strings. Origin: a template posted to `…/login/authenticate_post` while the controller
# class is AuthenticatePost. Verified in vendor: Router\ActionList::get() computes the lookup
# key as str_replace('_', '\\', strtolower(module . '\controller' . area . '\' . ns . '\' . action)),
# so an underscore becomes a NAMESPACE SEPARATOR, not a word boundary — `authenticate_post`
# looks for Controller\Login\Authenticate\Post and 404s to noroute. The comparison is
# case-insensitive, so camelCase vs lowercase is fine; only the underscore is fatal.
route_ids = set()
for routes_rel in ('etc/frontend/routes.xml', 'etc/adminhtml/routes.xml'):
    r = parse_xml(mod_path(*routes_rel.split('/')))
    if r is None:
        continue
    for route in r.iter('route'):
        owns = any((m.get('name') or '') == module_name for m in route.iter('module'))
        if not owns:
            continue
        for key in ('id', 'frontName'):
            if route.get(key):
                route_ids.add(route.get(key))

if route_ids:
    # Registered action keys, exactly as ActionList would compute them: path under Controller/
    # lowercased, separators normalised.
    action_keys = set()
    controller_root = mod_path('Controller')
    for path in walk_files(controller_root, ('.php',)) if os.path.isdir(controller_root) else []:
        rel = os.path.relpath(path, controller_root)[:-4]
        key = rel.replace(os.sep, '\\').lower()
        action_keys.add(key)
        if key.startswith('adminhtml\\'):
            action_keys.add(key[len('adminhtml\\'):])

    # ONLY strings passed to a URL builder. A bare 'a/b/c' literal is far more often a
    # scopeConfig path — and a module's config section id is usually identical to its route id,
    # so matching bare literals reported every single config path as a broken route.
    url_re = re.compile(
        r'''(?:getUrl|getDirectUrl|setPath|_redirect|getRedirectUrl|redirect)\s*\(\s*'''
        r'''['"]([a-z][a-z0-9_]*)/([a-zA-Z0-9_]+)(?:/([a-zA-Z0-9_]+))?['"]''')
    for path in (walk_files(mod_path('view'), ('.phtml',)) + php_files):
        text = read(path)
        for m in url_re.finditer(text):
            route, controller, action = m.group(1), m.group(2), m.group(3) or 'index'
            if route not in route_ids:
                continue
            # ActionList::get() appends 'action' when the segment is a PHP reserved word, which
            # is why the class for .../store/switch is SwitchAction.
            if action.lower() in ROUTER_RESERVED_WORDS:
                action += 'action'
            key = ('%s\\%s' % (controller, action)).replace('_', '\\').lower()
            if key in action_keys:
                continue
            add('SI-11', 'high',
                'Route "%s/%s/%s" resolves to no controller class' % (route, controller, action),
                'Router\\ActionList::get() builds its lookup key with '
                'str_replace(\'_\', \'\\\\\', strtolower(...)), so an underscore in a path '
                'segment becomes a namespace separator: this URL looks for Controller\\%s and '
                'no such class exists in the module. The request falls through to noroute and '
                'returns 404 — with no log entry, because a 404 is not an error. The lookup is '
                'case-insensitive, so only the segment SHAPE matters, not its casing.'
                % key.replace('\\', '\\'),
                [(path, line_of(path, m.group(0)))],
                'Use the camelCase (or lowercase) form that matches the class name — e.g. '
                'replace "%s" with the class\'s own spelling — or add the controller class at '
                'Controller/%s.php.' % (action, key.replace('\\', '/')),
                'Request the URL: it must return the controller\'s response, not the 404 page.')

print(json.dumps(findings, indent=2))
PY

rc=$?
if [ "$rc" -ne 0 ]; then
    echo "surface-invariants: checker aborted (exit $rc) — surface completeness was NOT checked" >&2
    echo "[]" > "$FINDINGS_FILE"
fi

echo "$FINDINGS_FILE"
