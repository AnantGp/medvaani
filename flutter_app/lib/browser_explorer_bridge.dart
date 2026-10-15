import 'dart:js_interop';

@JS('medivaaniiExplorerBridge.watch')
external void _watch(JSString frameId, JSFunction receive);
@JS('medivaaniiExplorerBridge.stop')
external void _stop(JSString frameId);

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
}
