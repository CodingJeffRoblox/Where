// Talks to the Where desktop app on this computer only (127.0.0.1).
// Shared by the popup and the background worker.

const WHERE_URL = 'http://127.0.0.1:47771';

/** Browser name shown in Where when asking for permission. */
function whereClientName() {
  const ua = navigator.userAgent;
  if (navigator.brave) return 'Brave';
  if (ua.includes('Edg/')) return 'Microsoft Edge';
  if (ua.includes('OPR/')) return 'Opera';
  if (ua.includes('Vivaldi')) return 'Vivaldi';
  return 'Chrome';
}

async function whereToken() {
  const { whereToken } = await chrome.storage.local.get('whereToken');
  return whereToken || null;
}

async function setWhereToken(token) {
  if (token) await chrome.storage.local.set({ whereToken: token });
  else await chrome.storage.local.remove('whereToken');
}

/**
 * Calls the Where app. Resolves to { ok, status, data }.
 * status 0 means Where isn't running (nothing answered).
 */
async function whereCall(path, { method = 'GET', body, timeoutMs = 5000 } = {}) {
  const token = await whereToken();
  const ctrl = new AbortController();
  const timer = timeoutMs ? setTimeout(() => ctrl.abort(), timeoutMs) : null;
  try {
    const res = await fetch(WHERE_URL + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { 'X-Where-Token': token } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: ctrl.signal,
    });
    let data = {};
    try { data = await res.json(); } catch (_) { /* empty body */ }
    return { ok: res.ok, status: res.status, data };
  } catch (_) {
    return { ok: false, status: 0, data: {} };
  } finally {
    if (timer) clearTimeout(timer);
  }
}

/** Only normal web pages can be saved. */
function isSavableUrl(url) {
  try {
    const u = new URL(url);
    return (u.protocol === 'http:' || u.protocol === 'https:') && !!u.hostname;
  } catch (_) {
    return false;
  }
}
