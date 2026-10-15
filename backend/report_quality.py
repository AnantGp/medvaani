"""Shared extraction acceptance policy. A review checkbox is not validation."""
import copy
import json
import math
import re
from decimal import Decimal, InvalidOperation
from report_records import ExtractedDocument, Measurement, QualityReport
from result_context import nonmeasurement_identity

OUTSIDE = {'high', 'low', 'critical', 'abnormal'}
QUALITATIVE = re.compile(r'^(?:pale yellow|yellow|clear|negative|positive|normal|nil|absent|trace|reactive|non[- ]?reactive|not detected|detected)$', re.I)


def normalized_unit(value):
    return re.sub(r'\s+', '', str(value)).casefold().replace('µ', 'u').replace('μ', 'u')


def valid_box(box):
    return (isinstance(box, list) and len(box) == 4 and all(isinstance(v, (int, float))
            and math.isfinite(v) for v in box) and 0 <= box[0] < 1 and 0 <= box[1] < 1
            and 0 < box[2] <= 1 and 0 < box[3] <= 1 and box[0] + box[2] <= 1.00001
            and box[1] + box[3] <= 1.00001)


def value_kind(value):
    value = str(value).strip().replace('–', '-').replace('−', '-')
    if re.fullmatch(r'[+-]?\d[\d,]*(?:\.\d+)?', value):
        return 'scalar'
    if re.fullmatch(r'[<>≤≥]\s*\d[\d,]*(?:\.\d+)?', value):
        return 'bounded'
    if re.fullmatch(r'\d+(?:\.\d+)?\s*-\s*\d+(?:\.\d+)?', value):
        return 'interval'
    if QUALITATIVE.fullmatch(value):
        return 'qualitative'
    return 'unreadable'


def _unit_problem(row):
    name = str(row.get('test_name', '')).casefold()
    unit = normalized_unit(row.get('unit', ''))
    allowed = None
    if 'thyroid stimulating' in name or re.search(r'\btsh\b', name):
        allowed = {'uiu/ml', 'uu/ml', 'miu/l'}
    elif 'creatinine' in name and 'ratio' not in name:
        allowed = {'mg/dl', 'umol/l', 'µmol/l'}
    elif 'vitamin d' in name and 'ratio' not in name:
        allowed = {'ng/ml', 'nmol/l'}
    elif 'vitamin b12' in name or 'vitamin b 12' in name:
        allowed = {'pg/ml', 'pmol/l'}
    elif 'glucose' in name and value_kind(row.get('value', '')) != 'qualitative':
        allowed = {'mg/dl', 'mmol/l'}
    return bool(allowed is not None and unit and unit not in allowed)


def _comparison(row):
    value, reference = str(row.get('value', '')), str(row.get('reference_range', '')).strip()
    if value_kind(value) == 'qualitative':
        return 'normal' if value.casefold() == reference.casefold() else None
    if value_kind(value) == 'bounded':
        return None
    match = re.fullmatch(r'\s*([+-]?[\d,.]+)\s*(?:-|–|to)\s*([+-]?[\d,.]+)\s*([^\d]*)', reference, re.I)
    if not match:
        return None
    if match[3].strip() and normalized_unit(match[3]) != normalized_unit(row.get('unit', '')):
        return None
    try:
        low, high = [Decimal(s.replace(',', '')) for s in match.group(1, 2)]
        if low > high:
            return None
        values = [Decimal(s.strip().replace(',', '')) for s in re.split(r'\s*[-–]\s*', value)] if value_kind(value) == 'interval' else [Decimal(value.replace(',', ''))]
        if max(values) < low:
            return 'low'
        if min(values) > high:
            return 'high'
        return 'normal' if min(values) >= low and max(values) <= high else None
    except (InvalidOperation, ValueError):
        return None


def _validated_row(original):
    row = copy.deepcopy(original)
    if row.get('record_type') == 'narrative':
        field = row.get('source_fields', {}).get('text', {})
        supported = (row.get('section') in {'findings', 'diagnosis', 'impression'} and row.get('text')
                     and row['text'] == field.get('text') and valid_box(field.get('box'))
                     and isinstance(field.get('page'), int) and field['page'] > 0)
        if field.get('method') in {'ocr', 'docling_ocr', 'groq_vision'} and 'text' not in row.get('source_checked_fields', []):
            supported = False
        row.update(acceptance_state='eligible' if supported else 'needs_review',
                   issues=[] if supported else [{'code': 'source_missing', 'field': 'text'}])
        return row
    corrections = row.get('corrections', {})
    issues = [i for i in row.get('issues', []) if isinstance(i, dict) and i.get('persistent')
              and not corrections.get(i.get('field'), {}).get('confirmed')]
    def issue(code, field=None):
        if not any(i.get('code') == code and i.get('field') == field for i in issues):
            issues.append({'code': code, 'field': field})
    if row.get('record_type') != 'measurement' or nonmeasurement_identity(row.get('test_name', '')):
        row.update(acceptance_state='rejected', issues=issues)
        return row
    if not row.get('measurement_id') or not str(row.get('test_name', '')).strip():
        issue('identity_missing', 'test_name')
    fields = row.get('source_fields', {})
    for key in ('test_name', 'value', 'unit', 'reference_range'):
        text = str(row.get(key, '')).strip()
        if not text and key in ('unit', 'reference_range'):
            continue
        field = fields.get(key, {})
        corrected = corrections.get(key, {})
        if not isinstance(field, dict) or not field.get('text') or not valid_box(field.get('box')) or not isinstance(field.get('page'), int) or field['page'] < 1:
            if key in ('unit', 'reference_range') and corrected.get('confirmed') is True and corrected.get('value') == text:
                continue
            issue('source_missing', key)
            continue
        if str(field['text']).strip() != text and not (corrected.get('confirmed') is True and corrected.get('value') == text):
            issue('source_mismatch', key)
        if field.get('method') in {'ocr', 'docling_ocr', 'groq_vision'} and key not in row.get('source_checked_fields', []) and not corrected.get('confirmed'):
            issue('ocr_source_check', key)
    value_source = fields.get('value', {})
    vbox = value_source.get('box')
    if valid_box(vbox):
        for key in ('test_name', 'unit', 'reference_range'):
            field = fields.get(key, {})
            if not str(row.get(key, '')).strip() or not valid_box(field.get('box')):
                continue
            box = field['box']
            if field.get('page') != value_source.get('page') or box[1] > vbox[1] + vbox[3] + .008 or box[1] + box[3] < vbox[1] - .008:
                issue('field_association', key)
    kind = value_kind(row.get('value', ''))
    row['value_kind'] = kind
    row['normalized_unit'] = normalized_unit(row.get('unit', ''))
    if kind == 'unreadable':
        issue('value_unreadable', 'value')
    if _unit_problem(row):
        issue('unit_incompatible', 'unit')
    comparison = _comparison(row) if not issues else None
    status = 'unknown'
    source = 'unknown'
    corrected_fields = any(corrections.get(k, {}).get('confirmed') for k in ('test_name', 'value', 'unit', 'reference_range'))
    flag = fields.get('flag', {})
    if flag.get('method') in {'ocr', 'docling_ocr', 'groq_vision'} and 'flag' not in row.get('source_checked_fields', []) and not corrections.get('status', {}).get('confirmed'):
        issue('ocr_source_check', 'flag')
    reported = {'h': 'high', 'high': 'high', 'l': 'low', 'low': 'low', 'normal': 'normal', 'n': 'normal',
                'abnormal': 'abnormal', 'critical': 'critical'}.get(str(flag.get('text', '')).strip().casefold())
    if corrections.get('status', {}).get('confirmed') and corrections['status'].get('value') in OUTSIDE | {'normal', 'unknown'}:
        status, source = corrections['status']['value'], 'user_review'
        if status in {'normal', 'high', 'low'} and comparison and status != comparison:
            issue('flag_range_conflict', 'status')
    elif reported and not corrected_fields and valid_box(flag.get('box')) and flag.get('page') == value_source.get('page'):
        status, source = reported, 'report'
        if reported in {'normal', 'high', 'low'} and comparison and comparison != reported:
            issue('flag_range_conflict', 'status')
    elif comparison:
        status, source = comparison, 'reviewed_range' if corrected_fields else 'reviewed_source' if row.get('source_checked_fields') else 'reference_range'
    row.update(status=status if not issues else 'unknown', status_source=source if not issues else 'unknown')
    row['issues'] = issues
    row['acceptance_state'] = 'needs_review' if issues else 'eligible'
    if not row.get('reference_range') and row.get('status_source') not in ('report', 'user_review'):
        row.update(status='unknown', status_source='unknown')
    return row


def validate_document(document: ExtractedDocument) -> tuple[list[Measurement], QualityReport]:
    rows = [_validated_row(r) for r in document.get('candidates', []) if isinstance(r, dict)]
    diagnostics = [d for d in document.get('diagnostics', []) if isinstance(d, dict)]
    failed = sorted({d['page'] for d in diagnostics if d.get('code') == 'page_failed' and isinstance(d.get('page'), int)})
    unresolved = sum(d.get('code') in {'unresolved_result_region', 'unsupported_layout', 'worker_failed', 'worker_timeout'} for d in diagnostics)
    eligible = sum(r.get('record_type') == 'measurement' and r.get('acceptance_state') == 'eligible' for r in rows)
    narratives = sum(r.get('record_type') == 'narrative' and r.get('acceptance_state') == 'eligible' for r in rows)
    uncertain = sum(r.get('acceptance_state') == 'needs_review' for r in rows)
    state = 'blocked' if not eligible and not narratives else 'partial' if uncertain or failed or unresolved else 'ready'
    return rows, {'state': state, 'eligible_count': eligible, 'needs_review_count': uncertain,
                  'eligible_narrative_count': narratives,
                  'unresolved_result_regions': unresolved, 'processed_pages': sorted({p['page'] for p in document.get('pages', []) if isinstance(p.get('page'), int)}),
                  'failed_pages': failed, 'issues': diagnostics, 'coverage_basis': 'Detected source result sections and candidate rows'}


def _parsed(report):
    parsed = report.get('parsed_data', {})
    try:
        parsed = json.loads(parsed) if isinstance(parsed, str) else parsed
    except (ValueError, TypeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def eligible_measurements(parsed: dict) -> list[Measurement]:
    return [checked for row in parsed.get('lab_values', []) if isinstance(row, dict)
            and row.get('record_type') == 'measurement'
            and (checked := _validated_row(row)).get('acceptance_state') == 'eligible']


def eligible_narratives(parsed):
    return [checked for row in parsed.get('source_narratives', []) if isinstance(row, dict)
            and row.get('record_type') == 'narrative'
            and (checked := _validated_row(row)).get('acceptance_state') == 'eligible']


def report_quality(report: dict) -> QualityReport:
    parsed = _parsed(report)
    if report.get('extraction_version', parsed.get('schema_version')) != 4:
        return {'state': 'legacy_unverified', 'eligible_count': 0, 'needs_review_count': len(parsed.get('lab_values', [])),
                'unresolved_result_regions': 1, 'failed_pages': [], 'processed_pages': [], 'issues': [],
                'coverage_basis': 'Original source must be read with layout-aware extraction'}
    metadata = parsed.get('document', {})
    _, quality = validate_document({**metadata, 'candidates': parsed.get('lab_values', []) + parsed.get('source_narratives', [])})
    return quality


def can_generate_report_output(report: dict) -> bool:
    return report_quality(report)['state'] in {'ready', 'partial'}
