// Local-only single-report cache. No network requests or third-party storage.
(() => {
  let database;
  function open() {
    if (!database) database = new Promise((resolve, reject) => {
      const request = indexedDB.open('medivaanii-report', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('current');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onblocked = () => reject(new Error('Report storage is blocked'));
    });
    return database;
  }
  async function transaction(mode, operation) {
    const db = await open();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('current', mode);
      let result;
      tx.oncomplete = () => resolve(result);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error || new Error('Storage operation aborted'));
      const request = operation(tx.objectStore('current'));
      request.onsuccess = () => { result = request.result; };
    });
  }
  window.medivaaniiReportStore = {
    save: (payload, source) => transaction('readwrite', store => store.put({payload, source}, 'report')),
    restore: () => transaction('readonly', store => store.get('report')),
    clear: () => transaction('readwrite', store => store.delete('report')),
  };
})();
// Compare native WindowProxy identities here. Legacy dart:html cross-frame
// wrappers do not implement equality, so they cannot validate message sources.
window.medivaaniiExplorerBridge = (() => {
  const listeners = new Map();
  const findFrame = (root, id) => {
    const found = root.getElementById?.(id) || root.querySelector('#' + CSS.escape(id));
    if (found) return found;
    for (const node of root.querySelectorAll('*')) {
      if (node.shadowRoot) {
        const nested = findFrame(node.shadowRoot, id);
        if (nested) return nested;
      }
    }
    return null;
  };
  return {
    watch(frameId, receive) {
      this.stop(frameId);
      let frame;
      const listener = event => {
        if (!frame?.isConnected) frame = findFrame(document, frameId);
        if (frame && event.origin === location.origin &&
            event.source === frame.contentWindow && typeof event.data === 'string') receive(event.data);
      };
      listeners.set(frameId, listener);
      addEventListener('message', listener);
    },
    stop(frameId) {
      const listener = listeners.get(frameId);
      if (listener) removeEventListener('message', listener);
      listeners.delete(frameId);
    }
  };
})();
