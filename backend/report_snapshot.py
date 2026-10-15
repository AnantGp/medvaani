"""Small client snapshots restore the single-user MVP after serverless cold starts."""
import json
import os

KEYS = {'report_id', 'parsed_data', 'extraction_version', 'extracted_text',
        'extraction_quality', 'input_type', 'report_date', 'review', 'target_language'}


def resolve_report(body, store):
    snapshot = body.get('report') or body.get('report_snapshot')
    if isinstance(snapshot, str):
        snapshot = json.loads(snapshot)
    if isinstance(snapshot, dict):
        snapshot = {key: value for key, value in snapshot.items() if key in KEYS}
        if not snapshot.get('parsed_data') and not snapshot.get('extracted_text'):
            raise ValueError('Upload a report first.')
        if len(json.dumps(snapshot).encode()) > 2_000_000:
            raise ValueError('This report snapshot is too large. Try a shorter report.')
        report_id = str(body.get('report_id') or snapshot.get('report_id') or '')
        if body.get('report_id') and snapshot.get('report_id') and body['report_id'] != snapshot['report_id']:
            raise ValueError('The report snapshot does not match this report.')
        if report_id:
            snapshot['report_id'] = report_id
        return store.save(snapshot)
    if os.getenv('VERCEL') == '1':
        raise ValueError('Send the current report snapshot with this request to restore the conversation.')
    return store.get(str(body.get('report_id', '')))


def recent_history(value):
    if isinstance(value, str):
        value = json.loads(value)
    if not isinstance(value, list):
        return []
    result = []
    for item in value[-8:]:
        if not isinstance(item, dict) or item.get('role') not in ('user', 'assistant'):
            continue
        content = item.get('content')
        if isinstance(content, str) and len(content) <= 8000:
            result.append({'role': item['role'], 'content': content})
    return result
