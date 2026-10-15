// Browser-only adapter; stores one local report and its source document.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('medivaaniiReportStore.save')
external JSPromise<JSAny?> _save(JSString payload, JSString? source);
@JS('medivaaniiReportStore.restore')
external JSPromise<JSAny?> _restore();
@JS('medivaaniiReportStore.clear')
external JSPromise<JSAny?> _clear();

extension type _StoredReport(JSObject value) implements JSObject {
  external JSString? get payload;
  external JSString? get source;
}

class SavedBrowserReport {
  const SavedBrowserReport(this.payload, this.sourceBytes);
  final String payload;
  final Uint8List? sourceBytes;
}

class BrowserReportStore {
  Future<void> save(String payload, Uint8List? source, String mime) async {
    await _save(payload.toJS, source == null ? null : base64Encode(source).toJS)
        .toDart;
  }

  Future<SavedBrowserReport?> restore() async {
    final record = await _restore().toDart;
    if (record == null) return null;
    final stored = _StoredReport(record as JSObject);
    final payload = stored.payload?.toDart;
    final source = stored.source?.toDart;
    if (payload == null) return null;
    return SavedBrowserReport(
        payload, source == null ? null : base64Decode(source));
  }

  Future<void> clear() async {
    await _clear().toDart;
  }
}
