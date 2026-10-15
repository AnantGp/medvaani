"""Report-grounded presentation, correction and bounded questions.

No clinical cutoffs, diagnosis inference or provider calls are made here.
"""
import json
import re
import copy
from datetime import datetime
from report_quality import eligible_measurements, eligible_narratives, report_quality, validate_document, can_generate_report_output

STATUSES = {"normal", "high", "low", "critical", "abnormal", "unknown"}
OUTSIDE = {"high", "low", "critical", "abnormal"}


def parsed_report(value):
    parsed = json.loads(value) if isinstance(value, str) else value
    if not isinstance(parsed, dict) or not isinstance(parsed.get("lab_values", []), list):
        raise ValueError("Report results are unavailable. Upload the report again.")
    return parsed


def result_status(row):
    status = str(row.get("status", "unknown")).strip().lower()
    return status if status in STATUSES else "unknown"


def real_labs(parsed):
    return eligible_measurements(parsed) if parsed.get('schema_version') == 4 else []


def primary_labs(parsed):
    return [row for row in parsed.get('lab_values', []) if isinstance(row, dict)
            and row.get('record_type', 'measurement') == 'measurement'
            and row.get('test_name') not in ('', None, 'Unknown Test')]


def result_description(row):
    status = result_status(row)
    source = row.get("status_source", "unknown")
    if status == "unknown":
        return "This result cannot be reliably classified from the available report flag and reference range. Check it against the original."
    if source == "report":
        return f"The report marks this result as {status}."
    if source == 'source_summary':
        return f"The uploaded summary lists this comparison as {status}. Check it against the laboratory report."
    if source in {"reference_range", "reviewed_source"}:
        relation = {"normal": "within", "high": "above", "low": "below"}.get(status)
        if relation:
            return f"The extracted value is {relation} the reference range shown in this report."
    if source == "user_review":
        return f"You marked this result as {status} during extraction review."
    if source == "reviewed_range":
        relation = {"normal": "within", "high": "above", "low": "below"}.get(status)
        if relation:
            return f"The corrected value is {relation} the reference range you entered during review."
    return f"The extracted status is {status}; its source has not been confirmed."


def overview(parsed):
    labs = real_labs(parsed)
    outside = sum(result_status(row) in OUTSIDE for row in labs)
    unknown = sum(result_status(row) == "unknown" for row in labs)
    normal = sum(result_status(row) == "normal" for row in labs)
    if not labs:
        return "No usable laboratory values were extracted. Review any report findings below."
    result_word = lambda count: "result" if count == 1 else "results"
    quality = report_quality({'parsed_data': parsed})
    parts = [f"{len(labs)} laboratory {result_word(len(labs))} extracted."]
    if quality['state'] == 'partial':
        parts.insert(0, f"Partial report: {quality['needs_review_count']} measurements or {quality['unresolved_result_regions']} result regions need source review.")
    if outside:
        parts.append("1 result has an abnormal flag or compares outside the supplied reference range." if outside == 1 else f"{outside} results have abnormal flags or compare outside the supplied reference range.")
    if normal:
        parts.append(f"{normal} {result_word(normal)} {'is marked normal or compares' if normal == 1 else 'are marked normal or compare'} within the supplied reference range.")
    if unknown:
        parts.append(f"{unknown} {result_word(unknown)} {'has' if unknown == 1 else 'have'} no supported comparison from the supplied reference fields. This does not establish that they are normal or abnormal.")
    return " ".join(parts)


def content(parsed):
    labs = real_labs(parsed)
    if not can_generate_report_output({'parsed_data': parsed}):
        message = 'No usable laboratory values were extracted with verified source fields. Read the original report again or correct the fields marked for review.'
        return {'medical_summary': message, 'simple_explanation': message,
                'suggestions': ['Read the original report again or choose a clearer report photo.'],
                'disease_explanation_en': '', 'solution_plan_en': message}
    lines = [overview(parsed), "", "Results in this report:"]
    for row in labs:
        name = str(row.get("test_name", "Test"))
        value = f"{row.get('value', 'Not provided')} {row.get('unit', '')}".strip()
        lines.extend([f"• {name}: {value}", result_description(row)])
        if row.get("reference_range"):
            lines.append(f"Reference range: {row['reference_range']}")
        lines.append("")
    for key, title in (("findings", "Clinical findings"), ("diagnosis", "Reported diagnosis"), ("impression", "Reported impression")):
        entries = [item['text'] for item in eligible_narratives(parsed) if item.get('section') == key]
        if entries:
            lines.extend([f"{title}:", *[f"• {item}" for item in entries], ""])
    lines.extend(["What should you do next?", "1. Check the extracted names, numbers, units and flags against your original report.",
                  "2. Discuss flagged or uncertain results with your healthcare professional.", "",
                  "Important: A reference-range comparison does not establish a diagnosis or an overall assessment of your health."])
    simple = "\n".join(lines)
    header = []
    if parsed.get("patient_name"):
        header.append(f"Patient: {parsed['patient_name']}")
    if parsed.get("report_date"):
        header.append(f"Report date: {parsed['report_date']}")
    suggestions = ["Check the extracted results against the original report.",
                   "Ask your healthcare professional what the flagged or uncertain results mean in your situation.",
                   "Bring this report and relevant previous reports to your appointment."]
    summary = header + [overview(parsed)]
    for row in labs:
        summary.append(f"• {row['test_name']}: {row.get('value', '')} {row.get('unit', '')} — {result_status(row)}")
    for key, title in (("findings", "Clinical findings"), ("diagnosis", "Reported diagnosis"), ("impression", "Reported impression")):
        entries = [item['text'] for item in eligible_narratives(parsed) if item.get('section') == key]
        if entries:
            summary.extend([f"{title}:", *[f"• {item}" for item in entries]])
    summary.append("Flags and range comparisons describe the report; they do not establish a diagnosis.")
    return {"medical_summary": "\n".join(summary), "simple_explanation": simple,
            "suggestions": suggestions, "disease_explanation_en": "",
            "solution_plan_en": "\n".join(f"{i}. {item}" for i, item in enumerate(suggestions, 1))}


def evidence(parsed, raw_text, previous=None):
    old = {item.get("lab_id"): item for item in previous or []}
    stable_old = {item.get('measurement_id'): item for item in previous or [] if item.get('measurement_id')}
    lines = raw_text.splitlines()
    sources = []
    for i, row in enumerate(primary_labs(parsed)):
        name = str(row.get("test_name", ""))
        value = str(row.get("value", ""))
        prior = stable_old.get(row.get('measurement_id'), old.get(i, {}))
        original = row.get('source_fields', {})
        if original:
            name = original.get('test_name', {}).get('text', name)
            value = original.get('value', {}).get('text', value)
        numeric_value = re.compile(r"(?<![\d.])" + re.escape(value) + r"(?![\d.])") if value else None
        quote = prior.get("source_quote") or row.get('source_quote') or next((line.strip() for line in lines if name.lower() in line.lower() and numeric_value and numeric_value.search(line)), None)
        if quote is None:
            quote = old.get(i, {}).get("source_quote")
        if quote and quote not in raw_text:
            quote = None
        snapshot = {**row, **{key: original.get(key, {}).get('text', '') for key in ('test_name', 'value', 'unit', 'reference_range')}, 'corrections': {}, 'source_checked_fields': []}
        original_checked, _ = validate_document({'candidates': [snapshot]})
        snapshot = original_checked[0]
        sources.append({"lab_id": i, "measurement_id": row.get('measurement_id'), 'source_fields': copy.deepcopy(original),
                        'acceptance_state': row.get('acceptance_state'), "test_name": name, "source_quote": quote,
                        "original_fields": prior.get("original_fields") if "original_fields" in prior else ({
                            key: snapshot.get(key, "") for key in ("test_name", "value", "unit", "reference_range", "status", "status_source")}
                            if quote and numeric_value and numeric_value.search(quote) else None),
                        "status_description": result_description(row)})
    return sources


def attach_review(response, raw_text, source_layout=None):
    parsed = parsed_report(response.get("parsed_data", {}))
    response["source_evidence"] = evidence(parsed, raw_text)
    response["source_layout"] = source_layout or []
    response["report_overview"] = overview(parsed)
    response["review"] = {"confirmed": False, "edited_lab_ids": []}
    response["explanation_version"] = 2
    response["extraction_version"] = 4 if parsed.get('schema_version') == 4 else 3
    response['extraction_quality'] = report_quality(response)
    return response


def reextract(report, extract_labs):
    """Upgrade an unconfirmed extraction using its original saved text."""
    if isinstance(report.get("review"), dict) and report["review"].get("confirmed"):
        raise ValueError("Your reviewed corrections are saved. Upload the original again to start a new extraction.")
    raise ValueError('The original document is needed to recover its layout. Upload the original report again; saved text alone cannot verify its measurements.')


def apply_review(report, rows, infer_status, parse_number):
    parsed = parsed_report(report.get("parsed_data", {}))
    if parsed.get('schema_version') != 4:
        raise ValueError('Read the original report again before confirming this older extraction. Your saved edits are retained.')
    original = primary_labs(parsed)
    original_sources = evidence(parsed, str(report.get("extracted_text", "")), report.get("source_evidence"))
    if not isinstance(rows, list) or len(rows) != len(original) or len(rows) > 500:
        raise ValueError("Review the same results extracted from this report.")
    corrected, changed = [], []
    for i, (old, row) in enumerate(zip(original, rows)):
        if not isinstance(row, dict):
            raise ValueError("Invalid result fields.")
        current = copy.deepcopy(old)
        checked_fields = row.get('source_checked_fields', old.get('source_checked_fields', []))
        if not isinstance(checked_fields, list) or any(k not in ('test_name', 'value', 'unit', 'reference_range', 'flag') for k in checked_fields):
            raise ValueError('Choose valid source fields to check.')
        current['source_checked_fields'] = list(dict.fromkeys(checked_fields))
        for key in ("test_name", "value", "unit", "reference_range"):
            value = row.get(key, "")
            if not isinstance(value, str) or len(value) > 256:
                raise ValueError("Result fields must be text shorter than 256 characters.")
            current[key] = value.strip()
        if not current["test_name"] or not current["value"]:
            raise ValueError("Each result needs a test name and value.")
        status = str(row.get("status", "unknown")).lower()
        if status not in STATUSES:
            raise ValueError("Choose a valid result flag.")
        edited_fields = [key for key in ('test_name', 'value', 'unit', 'reference_range') if current[key] != str(old.get(key, '')).strip()]
        fields_changed = bool(edited_fields)
        flag_changed = status != result_status(old)
        corrections = current.setdefault('corrections', {})
        for key in edited_fields:
            corrections[key] = {'value': current[key], 'confirmed': True, 'source': 'user_review'}
        if flag_changed or row.get("flag_override") is True:
            current.update(status=status, status_source="user_review" if status != "unknown" else "unknown")
            corrections['status'] = {'value': status, 'confirmed': True, 'source': 'user_review'}
        elif fields_changed:
            inferred = None if re.match(r"^[<>≤≥]", current["value"]) else infer_status(parse_number(current["value"]), current["reference_range"])
            current.update(status=inferred or "unknown", status_source="reviewed_range" if inferred else "unknown")
        else:
            current.update(status=result_status(old), status_source=old.get("status_source", "unknown"))
        if fields_changed or flag_changed:
            changed.append(i)
        corrected.append(current)
    checked, quality = validate_document({**parsed.get('document', {}), 'candidates': corrected})
    parsed["lab_values"] = checked
    result = {**report, **content(parsed), "parsed_data": json.dumps(parsed), "report_overview": overview(parsed),
              "source_evidence": evidence(parsed, str(report.get("extracted_text", "")), original_sources),
              "review": {"confirmed": True, "edited_lab_ids": changed, "reviewed_at": datetime.now().isoformat()},
              "explanation_version": 2, "translated_explanation": "", "translated_suggestions": [],
              "risk_probability": None, "causal_analysis": "", "temporal_analysis": "",
              'extraction_quality': quality,
              "validation": json.dumps({"is_valid": bool(quality['eligible_count']), "needs_review": bool(quality['needs_review_count']),
                  "confidence_score": None, "review_notes": "User-reviewed extraction; not clinical validation"}),
              "disease_explanation_lang": "", "disease_explanation_hi": "", "solution_plan_lang": "", "solution_plan_hi": ""}
    return result


def answer_question(report, question):
    if not isinstance(question, str) or not question.strip() or len(question) > 1000:
        raise ValueError("Ask a question of up to 1,000 characters.")
    parsed = parsed_report(report.get('parsed_data', {}))
    quality = report_quality(report)
    if not can_generate_report_output(report):
        return {'answer': 'The extraction needs source review before I can answer questions about its results. Read the original again or correct the uncertain fields.',
                'sources': [], 'supported': False, 'quality_state': quality['state']}
    labs = real_labs(parsed)
    q = question.casefold()
    sources = {item.get('measurement_id'): item for item in evidence(parsed, str(report.get('extracted_text', '')), report.get('source_evidence'))}
    if re.search(r'\b(medicine|medication|dose|treatment|diagnose|do i have)\b', q):
        return {'answer': 'This report alone cannot establish a diagnosis or choose a medicine, dose or treatment. Ask your healthcare professional to interpret it with your symptoms and medical history.',
                'sources': [], 'supported': False, 'quality_state': quality['state']}
    notes = eligible_narratives(parsed)
    if notes and (not labs or re.search(r'\b(findings|impression|diagnosis)\b', q)):
        return {'answer': '\n\n'.join(f"Reported {item['section']}: {item['text']}" for item in notes) + '\n\nThese are source statements, not a new diagnosis.',
                'sources': [{'measurement_id': item.get('measurement_id'), 'test_name': item['section'],
                             'source_quote': item.get('source_quote'), 'source_fields': item['source_fields']} for item in notes],
                'supported': True, 'quality_state': quality['state']}
    aliases = {'blood sugar': ('glucose', 'hba1c'), 'kidney': ('creatinine', 'egfr', 'bun'),
               'white blood': ('wbc', 'white blood'), 'red blood': ('hemoglobin', 'haemoglobin', 'hematocrit', 'rbc'),
               'tsh': ('thyroid stimulating', 'tsh'), 'vitamin d': ('vitamin d',), 'b12': ('vitamin b12',)}
    named = []
    for row in labs:
        name = str(row.get('test_name', '')).casefold()
        canonical = str(row.get('canonical_test', '')).replace('_', ' ')
        exact = bool(name and re.search(r'(?<!\w)' + re.escape(name) + r'(?!\w)', q))
        short = bool(canonical and re.search(r'(?<!\w)' + re.escape(canonical) + r'(?!\w)', q))
        alias = any(re.search(r'(?<!\w)' + re.escape(a) + r'(?!\w)', q) and any(term in name for term in terms)
                    for a, terms in aliases.items())
        if exact or short or alias:
            named.append(row)
    intent_text = q
    for row in named:
        intent_text = re.sub(r'(?<!\w)' + re.escape(str(row['test_name']).casefold()) + r'(?!\w)', '', intent_text)
    intent = ('high' if re.search(r'\b(high|higher|elevated|above)\b', intent_text) else
              'low' if re.search(r'\b(low|lower|below)\b', intent_text) else
              'outside' if re.search(r'\b(abnormal|flagged|outside)\b', intent_text) else
              'unknown' if re.search(r'\b(unknown|uncertain|unclassified)\b', intent_text) else None)
    selected = named if named else labs if intent or re.search(r'\b(summary|summarise|summarize|important|all results|my report)\b', q) else []
    if intent:
        selected = [row for row in selected if (result_status(row) in OUTSIDE if intent == 'outside' else result_status(row) == intent)]
    prefix = 'Partial report: only source-validated measurements are covered; other fields or result regions still need review.\n\n' if quality['state'] == 'partial' else ''
    if not selected:
        message = 'No extracted result has a supported flag or comparison matching this question. An unknown comparison does not establish that a result is normal.' if intent else 'I could not match this question to a source-validated result. I do not fill in missing or uncertain results.'
        return {'answer': prefix + message, 'sources': [], 'supported': bool(intent), 'quality_state': quality['state']}
    lines = []
    for row in selected:
        lines.extend([f"{row['test_name']}: {row.get('value', '')} {row.get('unit', '')}".strip(), result_description(row)])
        if row.get('reference_range'):
            lines.append(f"Reference range: {row['reference_range']}")
        lines.append('')
    return {'answer': prefix + '\n'.join(lines).strip(), 'sources': [sources[r['measurement_id']] for r in selected if r.get('measurement_id') in sources],
            'supported': True, 'quality_state': quality['state']}


def migrate_corrections(old, fresh, infer_status, parse_number):
    """Rebind overlays by immutable identity or unique original fields, never order."""
    previous = parsed_report(old.get('parsed_data', {}))
    parsed = parsed_report(fresh['parsed_data'])
    rows = copy.deepcopy(primary_labs(parsed))
    sources = evidence(previous, str(old.get('extracted_text', '')), old.get('source_evidence'))
    unapplied = copy.deepcopy(old.get('unapplied_corrections', []))
    edited = old.get('review', {}).get('edited_lab_ids', [])
    applied = False
    for index, row in enumerate(primary_labs(previous)):
        if index not in edited and not row.get('corrections') and not row.get('source_checked_fields'):
            continue
        source = sources[index].get('original_fields') if index < len(sources) else None
        matches = [r for r in rows if row.get('measurement_id') and r.get('measurement_id') == row['measurement_id']]
        if not matches and source:
            matches = [r for r in rows if all(str(r.get('source_fields', {}).get(k, {}).get('text', '')).strip() == str(source.get(k, '')).strip()
                       for k in ('test_name', 'value', 'unit', 'reference_range'))]
        if len(matches) != 1:
            unapplied.append({'original_fields': source, 'reviewed_fields': {k: row.get(k, '') for k in ('test_name', 'value', 'unit', 'reference_range', 'status')},
                              'reason': 'The original row could not be uniquely matched.'})
            continue
        target = matches[0]
        for key in ('test_name', 'value', 'unit', 'reference_range', 'status', 'source_checked_fields'):
            if key in row:
                target[key] = copy.deepcopy(row[key])
        applied = True
    if applied:
        fresh = apply_review(fresh, rows, infer_status, parse_number)
    fresh['unapplied_corrections'] = unapplied
    if unapplied:
        parsed = parsed_report(fresh['parsed_data'])
        parsed['document']['diagnostics'].append({'code': 'unresolved_result_region', 'reason': 'unapplied_corrections'})
        fresh.update(parsed_data=json.dumps(parsed), **content(parsed))
        fresh['extraction_quality'] = report_quality(fresh)
    return fresh
