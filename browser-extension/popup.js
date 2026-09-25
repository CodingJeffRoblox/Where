// Popup: save the current tab to Where with a title, note and project.

const $ = (id) => document.getElementById(id);
const views = ['loading', 'offline', 'unsupported', 'connect', 'form', 'saved'];
let tab = null;

function show(name) {
  for (const v of views) $('view-' + v).classList.toggle('hidden', v !== name);
  if (name === 'form') setTimeout(() => $('note').focus(), 50);
}

function setDot(state) {
  const dot = $('status-dot');
  dot.classList.toggle('on', state === 'on');
  dot.classList.toggle('off', state === 'off');
  dot.title = state === 'on' ? 'Connected to Where' : state === 'off' ? 'Where isn’t running' : 'Checking…';
}

async function start() {
  show('loading');
  [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !isSavableUrl(tab.url || '')) return show('unsupported');

  const status = await whereCall('/v1/status', { timeoutMs: 2500 });
  if (status.status === 0) {
    setDot('off');
    return show('offline');
  }
  setDot('on');
  if (!status.data.connected) return show('connect');
  await openForm();
}

async function openForm() {
  $('title').value = tab.title || '';
  const link = $('url');
  link.textContent = tab.url.replace(/^https?:\/\/(www\.)?/, '');
  link.href = tab.url;
  link.title = tab.url;
  const fav = $('favicon');
  if (tab.favIconUrl && /^(https?|data):/.test(tab.favIconUrl)) {
    fav.src = tab.favIconUrl;
    fav.onerror = () => { fav.style.display = 'none'; };
  } else {
    fav.style.display = 'none';
  }

  const [projects, existing] = await Promise.all([
    whereCall('/v1/projects'),
    whereCall('/v1/links/lookup?url=' + encodeURIComponent(tab.url)),
  ]);
  if (projects.status === 401) {
    await setWhereToken(null);
    return show('connect');
  }

  const select = $('project');
  for (const p of (projects.data.projects || [])) {
    const opt = document.createElement('option');
    opt.value = p.id;
    opt.textContent = p.title;
    select.appendChild(opt);
  }

  const saved = existing.data && existing.data.link;
  if (saved) {
    $('existing').classList.remove('hidden');
    $('title').value = saved.title || $('title').value;
    $('note').value = saved.note || '';
    if (saved.project_id) select.value = saved.project_id;
  } else {
    const { lastProject } = await chrome.storage.local.get('lastProject');
    if (lastProject && [...select.options].some((o) => o.value === lastProject)) select.value = lastProject;
  }
  show('form');
}

async function connect() {
  $('connect').disabled = true;
  $('connect-error').classList.add('hidden');
  $('connect-wait').classList.remove('hidden');
  await chrome.storage.local.remove('wherePairError');
  // The background worker keeps waiting even if this popup closes.
  chrome.runtime.sendMessage({ type: 'where-pair' });
}

// React when the background worker finishes pairing (popup still open).
chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== 'local') return;
  if (changes.whereToken && changes.whereToken.newValue && !$('view-connect').classList.contains('hidden')) {
    $('connect-wait').classList.add('hidden');
    openForm();
  }
  if (changes.wherePairError && changes.wherePairError.newValue) {
    $('connect-wait').classList.add('hidden');
    $('connect').disabled = false;
    $('connect-error').textContent = changes.wherePairError.newValue;
    $('connect-error').classList.remove('hidden');
  }
});

async function save() {
  const btn = $('save');
  btn.disabled = true;
  btn.textContent = 'Saving…';
  $('save-error').classList.add('hidden');
  const projectId = $('project').value || null;
  const r = await whereCall('/v1/links', {
    method: 'POST',
    body: {
      url: tab.url,
      title: $('title').value.trim(),
      note: $('note').value,
      project_id: projectId,
      client: whereClientName(),
    },
  });
  btn.disabled = false;
  btn.textContent = 'Save to Where';
  if (r.ok) {
    await chrome.storage.local.set({ lastProject: projectId || '' });
    $('saved-title').textContent = r.data.title || '';
    show('saved');
    setTimeout(() => window.close(), 1300);
    return;
  }
  if (r.status === 401) {
    await setWhereToken(null);
    return show('connect');
  }
  $('save-error').textContent =
    r.status === 0 ? 'Where isn’t running anymore. Open it and try again.' : (r.data.error || 'Couldn’t save.');
  $('save-error').classList.remove('hidden');
}

$('retry').addEventListener('click', start);
$('connect').addEventListener('click', connect);
$('save').addEventListener('click', save);
$('copy').addEventListener('click', async () => {
  await navigator.clipboard.writeText(tab.url);
  $('copy').textContent = '✓';
  setTimeout(() => { $('copy').textContent = '⧉'; }, 1200);
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && !$('view-form').classList.contains('hidden')) {
    e.preventDefault();
    save();
  }
});

start();
