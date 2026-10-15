import 'dart:js_interop';
import 'dart:typed_data';

@JS('medivaaniiExplorerBridge.watch')
external void _watch(JSString frameId, JSFunction receive);
@JS('medivaaniiExplorerBridge.stop')
external void _stop(JSString frameId);
@JS('medivaaniiExplorerBridge.source')
external void _source(
    JSString frameId, JSUint8Array bytes, JSString identity, JSString filename);

class BrowserExplorerBridge {
  String? _frameId;
  void watch(String frameId, void Function(String) receive) {
    stop();
    _frameId = frameId;
    _watch(frameId.toJS, ((JSString data) => receive(data.toDart)).toJS);
  }

  void stop() {
    if (_frameId != null) _stop(_frameId!.toJS);
    _frameId = null;
  }

  void source(Uint8List bytes, String identity, String filename) {
    if (_frameId != null) {
      _source(_frameId!.toJS, bytes.toJS, identity.toJS, filename.toJS);
    }
  }
}
