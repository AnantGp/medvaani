"""Decide pass/fail for an accuracy run. A green run means every limit held.

Limits live in thresholds.json. Service errors (quota, outages) are reported
separately and also fail the run: an item that was not scored is not a pass.
"""
import json, sys
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else 'out')
LIMITS = json.loads((Path(__file__).parent / 'thresholds.json').read_text())
FIELDS = ['expected', 'exact_name', 'name_errors', 'missing', 'extra', 'value_ok', 'value_wrong',
          'unit_wrong', 'range_wrong', 'status_ok', 'status_wrong', 'status_unlabelled', 'eligible']

failures, lines = [], []


def totals(items):
    t = {f: 0 for f in FIELDS}
    t['service_errors'] = 0
    for it in items:
        if it['outcome'] != 'scored':
            t['service_errors'] += 1
            t['expected'] += it.get('expected', 0)
            continue
        for f in FIELDS:
            t[f] += it.get(f, 0)
    return t


def check(group, t, limits):
    exp = max(t['expected'], 1)
    measured = {
        'value_wrong': t['value_wrong'], 'unit_wrong': t['unit_wrong'], 'range_wrong': t['range_wrong'],
        'status_wrong': t['status_wrong'], 'extra': t['extra'], 'name_errors': t['name_errors'],
        'service_errors': t['service_errors'],
        'min_exact_name_rate': t['exact_name'] / exp,
        'min_status_labelled_rate': t['status_ok'] / exp,
    }
    for key, limit in limits.items():
        got = measured[key]
        ok = got >= limit if key.startswith('min_') else got <= limit
        if not ok:
            failures.append(f'{group}: {key} = {round(got, 3)} (limit {limit})')
    lines.append(f"### {group}\n" + ', '.join(f'{k} {v}' for k, v in t.items()) +
                 f"\n\nexact-name rate {t['exact_name']}/{t['expected']}, correctly labelled {t['status_ok']}/{t['expected']}")


for mode in ('pdf', 'photo'):
    path = OUT / f'{mode}.json'
    if not path.exists():
        if mode == 'pdf':
            failures.append(f'{mode}: no results file (run did not complete)')
        else:
            lines.append(f'### {mode}\nnot run in this evaluation')
        continue
    data = json.loads(path.read_text())
    check(mode, totals(data['items']), LIMITS[mode])
    for it in data['items']:
        errs = it.get('errors') or ([it.get('error')] if it.get('error') else [])
        if errs:
            lines.append(f"- `{Path(it['item']).name}` ({it.get('state') or it['outcome']}): " + '; '.join(errs)[:900]
                         + (f" [diagnostics: {'; '.join(it['diagnostics'])[:300]}]" if it.get('diagnostics') else ''))
    qs = data.get('questions', [])
    if mode == 'pdf':
        passed = sum(q['outcome'] == 'pass' for q in qs)
        lines.append(f'### questions\n{passed}/{len(qs)} passed')
        if not qs:
            failures.append('questions: none were asked')
        if passed / max(len(qs), 1) < LIMITS['questions']['min_pass_rate']:
            failures.append(f"questions: pass rate {passed}/{len(qs)} (limit {LIMITS['questions']['min_pass_rate']})")
        for q in qs:
            if q['outcome'] != 'pass':
                lines.append(f"- [{q['outcome']}] `{Path(q['item']).stem}` {q['kind']}: {q['question']} — {q.get('why') or q.get('error')}\n  > {q.get('answer', '')[:600]}")

report = '## Accuracy run\n\n' + ('**PASSED**' if not failures else '**FAILED**\n\n' + '\n'.join(f'- {f}' for f in failures)) + '\n\n' + '\n'.join(lines)
(OUT / 'summary.md').write_text(report)
print(report)
# The run page summary is not reachable from every machine, so the detail
# also goes out as annotations of about 3.5 KB each.
chunk = ''
for line in report.splitlines():
    if len(chunk) + len(line) > 3400:
        print('::notice title=accuracy detail::' + chunk.replace('%', '%25').replace('\n', '%0A'))
        chunk = ''
    chunk += line[:3300] + '\n'
if chunk:
    print('::notice title=accuracy detail::' + chunk.replace('%', '%25').replace('\n', '%0A'))
# One short annotation so the verdict is visible on the commit.
print(f"::{'notice' if not failures else 'error'} title=accuracy verdict::" + ('PASSED' if not failures else ' / '.join(failures))[:3500].replace('%', '%25'))
sys.exit(1 if failures else 0)
