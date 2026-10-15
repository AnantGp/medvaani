"""Simple local MVP report state and recent conversation history."""
import json
import sqlite3
import time
import uuid
from pathlib import Path


class ReportState:
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.touch(mode=0o600, exist_ok=True)
        self.path.chmod(0o600)
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS voice_reports (id TEXT PRIMARY KEY, payload TEXT, updated REAL)')
            db.execute('CREATE TABLE IF NOT EXISTS voice_history (id INTEGER PRIMARY KEY, report_id TEXT, language TEXT, role TEXT, content TEXT)')

    def connect(self):
        return sqlite3.connect(self.path, timeout=15)

    def save(self, report):
        report = dict(report)
        report_id = str(report.get('report_id') or uuid.uuid4())
        # Discard credentials from the abandoned foundation draft, if a cache
        # created during that draft is restored.
        for key in ('report_access_token', 'revision_id', 'session_token'):
            report.pop(key, None)
        report['report_id'] = report_id
        encoded = json.dumps(report, ensure_ascii=False)
        with self.connect() as db:
            previous = db.execute('SELECT payload FROM voice_reports WHERE id=?', (report_id,)).fetchone()
            if previous and json.loads(previous[0]).get('parsed_data') != report.get('parsed_data'):
                db.execute('DELETE FROM voice_history WHERE report_id=?', (report_id,))
            db.execute('INSERT OR REPLACE INTO voice_reports VALUES (?,?,?)', (report_id, encoded, time.time()))
        return report

    def get(self, report_id):
        with self.connect() as db:
            row = db.execute('SELECT payload FROM voice_reports WHERE id=?', (report_id,)).fetchone()
        if not row:
            raise ValueError('Upload or restore your report before starting a conversation.')
        return json.loads(row[0])

    def history(self, report_id, language):
        with self.connect() as db:
            rows = db.execute('SELECT role,content FROM voice_history WHERE report_id=? AND language=? ORDER BY id DESC LIMIT 8',
                              (report_id, language)).fetchall()
        return [{'role': role, 'content': content} for role, content in reversed(rows)]

    def remember(self, report_id, language, question, answer):
        with self.connect() as db:
            db.executemany('INSERT INTO voice_history (report_id,language,role,content) VALUES (?,?,?,?)',
                           [(report_id, language, 'user', question), (report_id, language, 'assistant', json.dumps(answer, ensure_ascii=False))])
            db.execute('DELETE FROM voice_history WHERE report_id=? AND language=? AND id NOT IN '
                       '(SELECT id FROM voice_history WHERE report_id=? AND language=? ORDER BY id DESC LIMIT 8)',
                       (report_id, language, report_id, language))

    def last(self, report_id, language):
        for item in reversed(self.history(report_id, language)):
            if item['role'] == 'assistant':
                return json.loads(item['content'])
        raise ValueError('Ask a question first, then use Repeat or Slower.')
