"""Structured table adapter; Docling availability is not a validation claim."""
import copy
import re
from report_records import measurement_id
from report_quality import normalized_unit, value_kind
from digital_results import canonical_test
from result_context import nonmeasurement_identity, result_context


def _norm(value):
    return re.sub(r'\s+', '', str(value)).casefold().replace('µ', 'u').replace('μ', 'u').replace('–', '-')


def _box(cell, size):
    b = cell.get('bbox')
    if not b:
        return None
    width, height = size['width'], size['height']
    top, bottom = b['t'], b['b']
    if b.get('coord_origin') == 'BOTTOMLEFT':
        top, bottom = height - b['t'], height - b['b']
    return [b['l'] / width, min(top, bottom) / height, (b['r'] - b['l']) / width, abs(bottom - top) / height]


def _header(cells):
    labels = [re.sub(r'[^a-z]', '', c.get('text', '').casefold()) for c in cells]
    choices = [('testname', 'parameter', 'investigation'), ('value', 'result'), ('unit', 'units'),
               ('biorefinterval', 'referenceinterval', 'referencerange')]
    indices = [next((i for i, label in enumerate(labels) if label in options), None) for options in choices]
    return indices if all(i is not None for i in indices) else None


def _grid(data):
    if data.get('grid'):
        return data['grid']
    grid = [[{'text': ''} for _ in range(data.get('num_cols', 0))] for _ in range(data.get('num_rows', 0))]
    for cell in data.get('table_cells', []):
        for r in range(cell['start_row_offset_idx'], min(cell['end_row_offset_idx'], len(grid))):
            for c in range(cell['start_col_offset_idx'], min(cell['end_col_offset_idx'], len(grid[r]))):
                grid[r][c] = cell
    return grid


def extract_docling_results(document_json, source_digest):
    rows, diagnostics = [], []
    for ti, table in enumerate(document_json.get('tables', [])):
        if not table.get('prov'):
            continue
        page = table['prov'][0]['page_no']
        size = document_json.get('pages', {}).get(str(page), {}).get('size')
        if not size:
            continue
        grid = _grid(table.get('data', {}))
        header = next(((i, indices) for i, cells in enumerate(grid) if (indices := _header(cells))), None)
        if header is None:
            # Headerless four-column tables need the actual nearby source header.
            for text in document_json.get('texts', []):
                normalized = re.sub(r'[^a-z]', '', text.get('text', '').casefold())
                if not all(label in normalized for label in ('testname', 'value', 'unit', 'biorefinterval')):
                    continue
                prov = next((p for p in text.get('prov', []) if p.get('page_no') == page), None)
                if prov and table['data'].get('num_cols') == 4:
                    hb, tb = _box(prov, size), _box(table['prov'][0], size)
                    if hb and tb and 0 <= tb[1] - hb[1] < .25:
                        header = (-1, [0, 1, 2, 3])
                        break
        if header is None:
            diagnostics.append({'code': 'unparsed_table', 'page': page, 'table': ti})
            continue
        table_box = _box(table['prov'][0], size)
        preceding = []
        for item in document_json.get('texts', []):
            for prov in item.get('prov', []):
                box = _box(prov, size) if prov.get('page_no') == page else None
                if box and table_box and box[1] + box[3] <= table_box[1]:
                    preceding.append((box[1], item.get('text', '')))
        context = result_context(text for _, text in sorted(preceding))
        if context in {'historical', 'guideline'}:
            diagnostics.append({'code': 'nonmeasurement_row', 'page': page, 'table': ti, 'record_type': context})
            continue
        hi, indices = header
        for cells in grid[hi + 1:]:
            if len(cells) <= max(indices):
                continue
            selected = [cells[i] for i in indices]
            raw_name, value, unit, reference = [c.get('text', '').strip() for c in selected]
            if not raw_name or not value:
                continue
            if nonmeasurement_identity(raw_name):
                diagnostics.append({'code': 'nonmeasurement_row', 'page': page, 'table': ti, 'record_type': 'guideline'})
                continue
            if value_kind(value) == 'unreadable':
                diagnostics.append({'code': 'unresolved_result_region', 'page': page, 'table': ti})
                continue
            if unit and not re.search(r'[A-Za-zµμ%/]', unit):
                continue
            contaminated = bool(re.match(r'^(?:Machine|Method)\s*:', raw_name, re.I))
            name = raw_name if contaminated else re.split(r'\b(?:Method|Machine)\s*:', raw_name)[0].strip()
            fields = {}
            for key, cell, text in zip(['test_name', 'value', 'unit', 'reference_range'], selected, [name, value, unit, reference]):
                box = _box(cell, size)
                if text and box:
                    fields[key] = {'text': text, 'raw_cell_text': cell.get('text', ''), 'page': page, 'box': box, 'method': 'docling'}
            if 'value' not in fields:
                diagnostics.append({'code': 'unresolved_result_region', 'page': page, 'table': ti})
                continue
            row = {'measurement_id': measurement_id(source_digest, page, f'docling_table_{ti}', fields['value']['box']),
                   'record_type': 'measurement', 'test_name': name, 'canonical_test': canonical_test(name),
                   'panel': 'Laboratory results', 'value': value, 'unit': unit, 'reference_range': reference,
                   'reference_kind': 'categorical' if '\n' in reference else 'numeric' if reference else 'absent',
                   'source_fields': fields, 'status': 'unknown', 'status_source': 'unknown', 'issues': []}
            if contaminated:
                row['issues'].append({'code': 'identity_contaminated', 'field': 'test_name', 'persistent': True})
            rows.append(row)
    return rows, diagnostics


def _overlap(a, b):
    if not a or not b or a.get('page') != b.get('page'):
        return False
    aa, bb = a.get('box'), b.get('box')
    if not aa or not bb:
        return False
    width = max(0, min(aa[0] + aa[2], bb[0] + bb[2]) - max(aa[0], bb[0]))
    height = max(0, min(aa[1] + aa[3], bb[1] + bb[3]) - max(aa[1], bb[1]))
    return width * height / max(min(aa[2] * aa[3], bb[2] * bb[3]), 1e-12) > .35


def reconcile_measurements(native, docling):
    result = copy.deepcopy(native)
    for extra in docling:
        if extra.get('record_type') != 'measurement' or extra.get('acceptance_state') == 'rejected':
            continue
        match = next((r for r in result if _overlap(r.get('source_fields', {}).get('value'), extra.get('source_fields', {}).get('value'))), None)
        if match is None:
            result.append(copy.deepcopy(extra))
            continue
        if any(i.get('code') == 'identity_contaminated' for i in extra.get('issues', [])):
            continue  # Not a competing validated identity; keep the original native proof.
        for key in ('test_name', 'value', 'unit', 'reference_range'):
            a, b = _norm(match.get(key, '')), _norm(extra.get(key, ''))
            if a and b and a != b:
                match.setdefault('issues', []).append({'code': 'engine_conflict', 'field': key, 'persistent': True})
            elif not a and b:
                match[key] = extra[key]
                match['source_fields'][key] = copy.deepcopy(extra['source_fields'][key])
    return result
