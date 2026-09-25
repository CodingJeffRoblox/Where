// Right-click menu: "Save page to Where" and "Save link to Where".
importScripts('where-api.js');

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({ id: 'where-save-page', title: 'Save page to Where', contexts: ['page'] });
    chrome.contextMenus.create({ id: 'where-save-link', title: 'Save link to Where', contexts: ['link'] });
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const isLink = info.menuItemId === 'where-save-link';
  const url = isLink ? info.linkUrl : (tab && tab.url);
  const title = isLink ? (info.selectionText || '') : ((tab && tab.title) || '');
  const tabId = tab && tab.id;

  if (!url || !isSavableUrl(url)) return flash(tabId, '!', '#C62828', 'Only web pages can be saved to Where');
  if (!(await whereToken())) return flash(tabId, '!', '#EF6C00', 'Click the Where button first to connect this browser');

  // No "note" field: an existing note in Where is kept.
  const r = await whereCall('/v1/links', {
    method: 'POST',
    body: { url, title, client: whereClientName() },
  });
  if (r.ok) return flash(tabId, '✓', '#2E7D32', 'Saved to Where');
  if (r.status === 0) return flash(tabId, '!', '#C62828', 'Where isn’t running on this computer');
  if (r.status === 401) await setWhereToken(null);
  flash(tabId, '!', '#C62828', (r.data && r.data.error) || 'Couldn’t save to Where');
});

function flash(tabId, text, color, title) {
  const target = tabId ? { tabId } : {};
  chrome.action.setBadgeBackgroundColor({ ...target, color });
  chrome.action.setBadgeText({ ...target, text });
  chrome.action.setTitle({ ...target, title });
  setTimeout(() => {
    chrome.action.setBadgeText({ ...target, text: '' });
    chrome.action.setTitle({ ...target, title: 'Save to Where (Alt+Shift+W)' });
  }, 3000);
}

// Pairing runs here, not in the popup: the popup closes as soon as you
// switch to the Where window to click Allow.
let pairing = null;
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (!msg || msg.type !== 'where-pair') return false;
  if (!pairing) {
    pairing = (async () => {
      const r = await whereCall('/v1/pair', { method: 'POST', body: { client: whereClientName() }, timeoutMs: 0 });
      if (r.ok && r.data.token) {
        await setWhereToken(r.data.token);
        flash(null, '✓', '#2E7D32', 'Connected to Where — click to save this page');
        return { ok: true };
      }
      const error = r.status === 0 ? 'Where stopped responding. Is it still open?' : (r.data.error || 'Couldn’t connect.');
      await chrome.storage.local.set({ wherePairError: error });
      return { ok: false, error };
    })().finally(() => { pairing = null; });
  }
  pairing.then(sendResponse);
  return true; // respond asynchronously
});
