"""Read clinical fields from source columns, never from flattened number lines."""
import re
from datetime import datetime
from report_records import measurement_id
from report_quality import value_kind
from result_context import nonmeasurement_identity, result_context


def source_field(words, page, method):
    if not words:
        return None
    x, y = min(w['x'] for w in words), min(w['y'] for w in words)
    right = max(w['x'] + w['width'] for w in words)
    bottom = max(w['y'] + w['height'] for w in words)
    return {'text': ' '.join(w['text'] for w in words), 'page': page,
            'box': [x, y, right - x, bottom - y], 'method': method}


def _columns(words, boundaries):
    result = [[], [], [], []]
    for word in words:
        result[sum(word['x'] >= boundary for boundary in boundaries)].append(word)
    return result


def canonical_test(name):
    n = name.casefold()
    for key, patterns in [('tsh', ('thyroid stimulating', 'tsh')), ('creatinine', ('creatinine',)),
                          ('egfr', ('gfr, estimated', 'egfr')), ('vitamin_d', ('vitamin d',)),
                          ('vitamin_b12', ('vitamin b12',)), ('hba1c', ('hba1c', 'glycosylated hemoglobin')),
                          ('glucose', ('glucose',)), ('hemoglobin', ('hemoglobin', 'haemoglobin'))]:
        if any(p in n for p in patterns):
            return key
    return ''


def _context(lines):
    text = '\n'.join(l['text'] for l in lines)
    date = re.search(r'Sample\s+(?:Collected\s+On|Collection\s+Date)\s*:\s*(\d{1,2}/[A-Za-z]{3}/\d{4})', text, re.I)
    sample_date = None
    if date:
        try:
            sample_date = datetime.strptime(date[1], '%d/%b/%Y').date().isoformat()
        except ValueError:
            pass
    specimen = re.search(r'Sample\s+Type\s*:\s*([^\n]+)', text, re.I)
    # Metadata columns may share a line; stop at the next known metadata label.
    specimen_text = re.split(r'\s+(?:Report\s+Status|Barcode)\s*:', specimen[1])[0].strip() if specimen else None
    return sample_date, specimen_text


def extract_digital_results(pages, source_digest):
    records, diagnostics, summary_pages = [], [], []
    document_profile = any('healthians' in re.sub(r'[^a-z]', '', l['text'].casefold())
                           for p in pages for l in p.get('lines', []))
    for page in pages:
        lines = page.get('lines', [])
        number = page['page']
        provider_known = document_profile
        headers = []
        for i, line in enumerate(lines):
            labels = [w['text'].casefold() for w in line['words']]
            if all(word in labels for word in ['test', 'name', 'value', 'unit']):
                ref = next((w for w in line['words'] if w['text'].casefold().startswith(('bio.', 'reference', 'ref'))), None)
                if ref is not None:
                    headers.append((i, line, ref))
        sample_date, specimen = _context(lines)
        for hi, (start, header, reference_header) in enumerate(headers):
            finish = headers[hi + 1][0] if hi + 1 < len(headers) else len(lines)
            context = result_context(l['text'] for l in lines[:start])
            if context in {'historical', 'guideline'}:
                diagnostics.append({'code': 'nonmeasurement_row', 'page': number, 'record_type': context})
                continue
            left = next(w['x'] for w in header['words'] if w['text'].casefold() == 'test')
            boundaries = [next(w['x'] for w in header['words'] if w['text'].casefold() == label) - .001 for label in ['value', 'unit']]
            boundaries.append(reference_header['x'] - .001)
            if boundaries != sorted(boundaries) or boundaries[0] <= left:
                diagnostics.append({'code': 'unresolved_result_region', 'page': number})
                continue
            if not provider_known:
                diagnostics.append({'code': 'unsupported_layout', 'page': number})
            flag_x = next((w['x'] - .001 for w in header['words'] if w['text'].casefold() == 'flag'), None)
            def table_columns(words):
                return _columns([w for w in words if flag_x is None or w['x'] < flag_x], boundaries)
            panel = 'Laboratory results'
            for i in range(start + 1, finish):
                line = lines[i]
                words = line['words']
                if not words or words[0]['x'] > left + .025:
                    continue
                cols = table_columns(words)
                text = [' '.join(w['text'] for w in col) for col in cols]
                name, value, unit, reference = text
                # Numbered interpretation paragraphs are prose. A clinical row
                # with an unreadable value must survive for source review.
                if re.match(r'^\d+[.)]\s', name):
                    continue
                if nonmeasurement_identity(name):
                    diagnostics.append({'code': 'nonmeasurement_row', 'page': number, 'record_type': 'guideline'})
                    continue
                if not value and not unit and not reference:
                    if name and not re.match(r'^(?:Method|Machine|Interpretation|Healthians|Note|Page)\b', name, re.I) and line['box'][3] > header['box'][3] * 1.08:
                        panel = name
                    continue
                if not name or name.startswith(('Method:', 'Machine:')) or (not value and not unit):
                    continue
                next_y = next((l['box'][1] for l in lines[i + 1:finish]
                               if l['words'] and l['words'][0]['x'] <= left + .025
                               and value_kind(' '.join(w['text'] for w in table_columns(l['words'])[1])) != 'unreadable'), 1)
                method_below = any(re.match(r'^Method\s*:', l['text'], re.I)
                                   and 0 < l['box'][1] - line['box'][1] < .05 and l['box'][1] < next_y
                                   for l in lines[i + 1:finish])
                ratio_context = unit.casefold() == 'ratio' and 'ratio' in name.casefold() and any(
                    re.match(r'^Method\s*:', l['text'], re.I) and 0 < line['box'][1] - l['box'][1] < .025 for l in lines[max(start, i - 3):i])
                if provider_known and not method_below and not ratio_context:
                    diagnostics.append({'code': 'nonmeasurement_row', 'page': number, 'record_type': 'guideline'})
                    continue
                fields = {key: field for key, col in zip(['test_name', 'value', 'unit', 'reference_range'], cols)
                          if (field := source_field(col, number, line['method'])) is not None}
                if flag_x is not None:
                    flag = source_field([w for w in words if w['x'] >= flag_x], number, line['method'])
                    if flag:
                        fields['flag'] = flag
                if cols[3]:
                    reference_parts = [fields['reference_range']]
                    for following in lines[i + 1:finish]:
                        if following['box'][1] >= next_y:
                            break
                        other = table_columns(following['words'])
                        first = ' '.join(w['text'] for w in other[0])
                        if first and not re.match(r'^(?:Method|Machine)\s*:', first, re.I):
                            break
                        if other[3]:
                            continuation = source_field(other[3], number, following['method'])
                            # Continue a reference rule, not arbitrary right-aligned
                            # page furniture or numeric prose below the result block.
                            if value_kind(continuation['text']) == 'unreadable' and not re.search(
                                    r'[<>≤≥]|\d\s*(?:-|to)(?:\s*\d|\s*$)', continuation['text'], re.I):
                                break
                            reference_parts.append(continuation)
                    ref_words = [w for following in lines[i:finish] for w in table_columns(following['words'])[3]
                                 if any(part['box'][1] <= w['y'] <= part['box'][1] + part['box'][3] for part in reference_parts)]
                    full = source_field(ref_words, number, line['method'])
                    full['text'] = '\n'.join(p['text'] for p in reference_parts)
                    full['boxes'] = [p['box'] for p in reference_parts]
                    fields['reference_range'] = full
                    reference = full['text']
                records.append({'measurement_id': measurement_id(source_digest, number, 'result_table', fields.get('value', {}).get('box', line['box'])),
                                'record_type': 'measurement', 'test_name': name, 'canonical_test': canonical_test(name),
                                'panel': panel, 'value': value, 'value_kind': value_kind(value), 'unit': unit,
                                'reference_range': reference, 'reference_kind': 'absent' if not reference else 'qualitative' if value_kind(reference) == 'qualitative' else 'categorical' if '\n' in reference else 'numeric',
                                'sample_date': sample_date, 'specimen': specimen, 'source_fields': fields,
                                'source_quote': line['text'],
                                'status': 'unknown', 'status_source': 'unknown', 'issues': []})
        if not headers:
            summary_pages.append(page)
    records.extend(extract_summary_results(summary_pages, source_digest, diagnostics))
    return records, diagnostics


def extract_summary_results(pages, digest, diagnostics):
    """Follow explicit result sections across pages, retaining printed locations."""
    numeric = r'[<>≤≥]?\s*[+-]?\d[\d,]*(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?'
    qualitative = r'pale yellow|light yellow|yellow|clear|non[- ]?reactive|not detected|negative|positive|reactive|detected|absent|normal|nil|trace'
    pattern = re.compile(r'^\s*[•●·\-]?\s*([A-Za-z][A-Za-z0-9 /()%.,+\-]{1,100}):\s*(' + numeric + '|' + qualitative + r')\s*(.*?)\s*$', re.I)
    category_terms = r'deficient|insufficient|sufficient|adequate|desirable(?:/low risk)?|optimal|near\s*/?\s*above optimal|borderline(?: high)?|very high|high|low|moderate|(?:line/)?(?:low|moderate|high|elevated/high)\s*risk'
    category = re.compile(r'^(?:' + category_terms + r')$', re.I)
    reference_continuation = re.compile(r'^(?:[<>≤≥+\-]?\s*\d|(?:' + category_terms + r')\s*[:\-])', re.I)
    reference_label = re.compile(r'^Reference\s*(?:range|interval)\s*:\s*(.*)$', re.I)
    flag_label = re.compile(r'^(?:Report\s*flag\s*or\s*supplied[- ]range\s*comparison|(?:Report\s*)?flag)\s*:\s*(high|low|normal|abnormal|critical|H|L|N)\s*$', re.I)
    furniture = re.compile(r'^(?:Medical Report Summary|Generated\s*by|Medivaanii.*(?:summary|Page)|Page\s*\d+\s*of\s*\d+)', re.I)
    rows, entries, context = [], [], 'unknown'
    page_context = {page['page']: _context(page.get('lines', [])) for page in pages}
    for page in pages:
        for line in page.get('lines', []):
            entries.append({**line, 'page': page['page']})
    def match_result(line):
        if flag_label.match(line['text']) or reference_label.match(line['text']):
            return None
        m = pattern.match(line['text'])
        if not m or nonmeasurement_identity(m[1]) or category.fullmatch(m[1].strip()):
            return None
        if re.search(r'\b(?:results? extracted|page|generated|patient|date|id)\b', m[1], re.I):
            return None
        return m
    def field(line, start, end, value):
        cursor, selected = 0, []
        for word in line.get('words', []):
            stop = cursor + len(word['text'])
            if cursor < end and stop > start:
                selected.append(word)
            cursor = stop + 1
        found = source_field(selected, line['page'], line['method'])
        if found:
            found.update(raw_cell_text=found['text'], text=value)
        return found
    def joined(parts, value, relationship):
        first = dict(parts[0])
        first.update(text=value, relationship=relationship, fragments=parts,
                     boxes=[p['box'] for p in parts if p['page'] == first['page']])
        return first
    for i, line in enumerate(entries):
        content = line['text'].strip()
        nearest = result_context([content])
        if nearest != 'unknown':
            context = nearest
        declared = re.match(r'^(\d+)\s*(?:usable measurements|laboratory results extracted|laboratory results|measurements extracted)\b', content, re.I)
        if declared:
            diagnostics.append({'code':'declared_measurement_count', 'page':line['page'], 'count':int(declared[1])})
        m = match_result(line)
        if not m:
            continue
        if context != 'current':
            if context == 'unknown':
                diagnostics.append({'code':'unresolved_result_region','page':line['page']})
            else:
                diagnostics.append({'code':'nonmeasurement_row','page':line['page'],'record_type':context})
            continue
        name, value, unit = [part.strip() for part in m.groups()]
        unit = re.split(r'\b(?:Comparison\s*unavailable|Report\s*flag)\b', unit, flags=re.I)[0].strip()
        inline = re.fullmatch(r'(.*?)\s*\(\s*(?:Reference|Ref|Reference\s*range)\s*:\s*(.*?)\)\s*(?:[-–]\s*(High|Low|Normal|Abnormal))?', unit, re.I)
        reference, parts = '', []
        fields = {'test_name':field(line,m.start(1),m.end(1),name), 'value':field(line,m.start(2),m.end(2),value)}
        if inline:
            unit, reference = inline[1].strip(), inline[2].strip()
            start = content.find(reference, m.start(3))
            parts.append(field(line,start,start+len(reference),reference))
            if inline[3]:
                start = content.rfind(inline[3]); fields['flag'] = field(line,start,start+len(inline[3]),inline[3])
        unit = re.sub(r'\s*\((?:high|low|normal|abnormal)\)\s*$', '', unit, flags=re.I).strip()
        if len(unit)>40 or re.search(r'\b(?:means|might|doctor|should|report)\b', unit, re.I):
            diagnostics.append({'code':'unresolved_result_region','page':line['page']});continue
        if unit:
            start = content.find(unit, m.start(3)); fields['unit'] = field(line,start,start+len(unit),unit)
        for following in entries[i+1:]:
            s = following['text'].strip()
            if following['page'] > line['page'] + 1 or match_result(following):
                break
            if furniture.match(s):
                continue
            rm, fm = reference_label.match(s), flag_label.match(s)
            if rm and not inline:
                reference = rm[1].strip()
                part = field(following,rm.start(1),rm.end(1),reference)
                if part: parts = [part]
            elif fm:
                flag = field(following,fm.start(1),fm.end(1),fm[1])
                if flag:
                    flag['relationship'] = 'labeled_following_flag'
                    if s.lower().startswith('report flag or'):
                        flag['origin'] = 'summary_comparison'
                    fields['flag'] = flag
                if parts:
                    break
            elif re.search(r'Comparison\s*unavailable', s, re.I):
                before = re.split(r'Comparison\s*unavailable', s, flags=re.I)[0].strip()
                if parts and before:
                    part = field(following,0,len(before),before)
                    if part: parts.append(part);reference += '\n' + before
                break
            elif parts and reference_continuation.match(s):
                part = field(following,0,len(s),s)
                if part: parts.append(part);reference += '\n' + s
            else:
                break
        parts = [p for p in parts if p]
        if parts:
            fields['reference_range'] = joined(parts,reference,'labeled_following_reference')
        fields = {k:v for k,v in fields.items() if v}
        if not fields.get('value'):
            diagnostics.append({'code':'unresolved_result_region','page':line['page']});continue
        date, specimen = page_context[line['page']]
        rows.append({'measurement_id':measurement_id(digest,line['page'],'summary_result',fields['value']['box']),
                     'record_type':'measurement','test_name':name,'canonical_test':canonical_test(name),
                     'panel':'Results in this report','value':value,'unit':unit,'reference_range':reference,
                     'sample_date':date,'specimen':specimen,'source_fields':fields,
                     'source_quote':line['text'],'extraction_method':'summary_result','status':'unknown','status_source':'unknown','issues':[]})
    return rows
