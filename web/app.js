// ── Kora Web Configuration ─────────────────────────────
// Central config — update this one line when migrating to a custom domain
const KORA_CONFIG = {
  BASE_URL: 'https://solas-463874c8.base44.app/functions',
  POLL_INTERVAL: 3000,
  get AUTH_URL() { return `${this.BASE_URL}/koraAuth`; },
  get CHAT_SYNC_URL() { return `${this.BASE_URL}/koraChatSync`; },
  get WEB_PAIR_URL() { return `${this.BASE_URL}/koraWebPair`; },
  get LOOKUP_URL() { return `${this.BASE_URL}/koraLookup`; },
};

// ── State ─────────────────────────────────────────────
let currentUser = null;
let conversations = [];
let messages = [];
let activeChatId = null;
let activeChatMessages = [];
let lastPollTimestamp = null;
let pollTimer = null;
let pendingLoginEmail = '';

// ── DOM Helpers ────────────────────────────────────────
const $ = (id) => document.getElementById(id);
const escapeHtml = (s) => String(s || '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function getInitials(name) {
  if (!name) return '?';
  return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
}

function getAvatarHtml(avatarUrl, name) {
  if (avatarUrl) return `<img src="${avatarUrl}" alt="" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
  return getInitials(name);
}

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
  }
  const diff = (now - d) / (1000 * 60 * 60 * 24);
  if (diff < 7) return d.toLocaleDateString('en-US', { weekday: 'short' });
  return d.toLocaleDateString('en-US', { month: 'numeric', day: 'numeric', year: '2-digit' });
}

function formatDateSeparator(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) return 'Today';
  const y = new Date(now); y.setDate(y.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return 'Yesterday';
  const diff = (now - d) / (1000 * 60 * 60 * 24);
  if (diff < 7) return d.toLocaleDateString('en-US', { weekday: 'long' });
  return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
}

// ── API helper ─────────────────────────────────────────
async function api(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`Server error (${res.status}): ${txt.slice(0, 100)}`);
  }
  return res.json();
}

// ── Device ID (persistent per browser) ─────────────────
function getDeviceId() {
  let id = localStorage.getItem('kora_web_device_id');
  if (!id) {
    id = 'web_' + Date.now() + '_' + Math.random().toString(36).substring(2, 12);
    localStorage.setItem('kora_web_device_id', id);
  }
  return id;
}

function getDeviceName() {
  const ua = navigator.userAgent;
  let browser = 'Unknown Browser';
  if (/Chrome/.test(ua) && !/Edg/.test(ua)) browser = 'Chrome';
  else if (/Firefox/.test(ua)) browser = 'Firefox';
  else if (/Safari/.test(ua) && !/Chrome/.test(ua)) browser = 'Safari';
  else if (/Edg/.test(ua)) browser = 'Edge';
  let os = 'Unknown OS';
  if (/Windows/.test(ua)) os = 'Windows';
  else if (/Mac/.test(ua)) os = 'macOS';
  else if (/Android/.test(ua)) os = 'Android';
  else if (/iPhone|iPad/.test(ua)) os = 'iOS';
  else if (/Linux/.test(ua)) os = 'Linux';
  return `${browser} on ${os}`;
}

// ── Session persistence ────────────────────────────────
// "Stay logged in" — when checked (default), session persists in localStorage.
// When unchecked, session lives only in sessionStorage and clears on browser close.
function saveSession() {
  const stay = $('stayLoggedInCheck')?.checked ?? true;
  if (currentUser) {
    const data = JSON.stringify(currentUser);
    if (stay) {
      localStorage.setItem('kora_web_user', data);
      sessionStorage.removeItem('kora_web_user');
    } else {
      sessionStorage.setItem('kora_web_user', data);
      localStorage.removeItem('kora_web_user');
    }
  } else {
    localStorage.removeItem('kora_web_user');
    sessionStorage.removeItem('kora_web_user');
  }
}

function loadSession() {
  const saved = localStorage.getItem('kora_web_user') || sessionStorage.getItem('kora_web_user');
  if (saved) { try { return JSON.parse(saved); } catch { return null; } }
  return null;
}

// ════════════════════════════════════════════════════════
// AUTH
// ════════════════════════════════════════════════════════

async function handleLogin() {
  const email = $('loginEmail').value.trim();
  const password = $('loginPassword').value;
  const errorDiv = $('loginError');
  const btn = $('loginBtn');

  if (!email) { errorDiv.textContent = 'Please enter your email'; errorDiv.style.display = 'block'; return; }
  if (!password) { errorDiv.textContent = 'Please enter your password'; errorDiv.style.display = 'block'; return; }

  errorDiv.style.display = 'none';
  btn.disabled = true;
  btn.textContent = 'Logging in...';

  try {
    const res = await api(KORA_CONFIG.AUTH_URL, {
      action: 'login',
      email, password,
      deviceId: getDeviceId(),
      deviceName: getDeviceName(),
      platform: 'web',
    });

    if (res.success && res.user) {
      currentUser = res.user;
      saveSession();
      showApp();
    } else if (res.needsDeviceVerification) {
      pendingLoginEmail = email;
      showVerificationScreen();
    } else {
      errorDiv.textContent = res.error || 'Login failed';
      errorDiv.style.display = 'block';
    }
  } catch (e) {
    errorDiv.textContent = 'Unable to connect. Please check your connection and try again.';
    errorDiv.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Log In';
  }
}

function showVerificationScreen() {
  $('loginScreen').style.display = 'none';
  $('verificationScreen').style.display = 'flex';
  $('verifyEmailLabel').textContent = `Enter the code sent to ${pendingLoginEmail}`;
  $('verifyCode1').focus();
}

async function handleVerify() {
  const code = ['verifyCode1','verifyCode2','verifyCode3','verifyCode4','verifyCode5','verifyCode6']
    .map(id => $(id).value).join('');

  if (code.length < 6) {
    $('verifyError').textContent = 'Please enter the full 6-digit code';
    $('verifyError').style.display = 'block';
    return;
  }

  $('verifyError').style.display = 'none';
  $('verifyBtn').disabled = true;
  $('verifyBtn').textContent = 'Verifying...';

  try {
    const res = await api(KORA_CONFIG.AUTH_URL, {
      action: 'verifyLogin',
      email: pendingLoginEmail,
      code,
      deviceId: getDeviceId(),
      deviceName: getDeviceName(),
      platform: 'web',
      recognizeDevice: true,
    });

    if (res.success && res.user) {
      currentUser = res.user;
      saveSession();
      showApp();
    } else {
      $('verifyError').textContent = res.error || 'Verification failed';
      $('verifyError').style.display = 'block';
      ['verifyCode1','verifyCode2','verifyCode3','verifyCode4','verifyCode5','verifyCode6']
        .forEach(id => $(id).value = '');
      $('verifyCode1').focus();
    }
  } catch (e) {
    $('verifyError').textContent = 'Connection error. Please try again.';
    $('verifyError').style.display = 'block';
  } finally {
    $('verifyBtn').disabled = false;
    $('verifyBtn').textContent = 'Verify';
  }
}

function backToLogin() {
  $('verificationScreen').style.display = 'none';
  $('loginScreen').style.display = 'flex';
  pendingLoginEmail = '';
  ['verifyCode1','verifyCode2','verifyCode3','verifyCode4','verifyCode5','verifyCode6']
    .forEach(id => $(id).value = '');
}

function logout() {
  currentUser = null;
  localStorage.removeItem('kora_web_user');
  sessionStorage.removeItem('kora_web_user');
  if (pollTimer) clearInterval(pollTimer);
  $('app').style.display = 'none';
  $('loginScreen').style.display = 'flex';
  $('loginEmail').value = '';
  $('loginPassword').value = '';
}

// ════════════════════════════════════════════════════════
// APP
// ════════════════════════════════════════════════════════

function showApp() {
  $('loginScreen').style.display = 'none';
  $('verificationScreen').style.display = 'none';
  $('app').style.display = 'flex';

  const avatarEl = $('myAvatar');
  const nameEl = $('myName');
  if (currentUser.avatarUrl) {
    avatarEl.innerHTML = `<img src="${currentUser.avatarUrl}" alt="" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
  } else {
    avatarEl.textContent = getInitials(currentUser.fullName || currentUser.email);
  }
  nameEl.textContent = currentUser.fullName || currentUser.email;

  loadChats();
  startMessagePolling();
}

async function loadChats() {
  try {
    const res = await api(KORA_CONFIG.CHAT_SYNC_URL, {
      action: 'fetch',
      userEmail: currentUser.email,
    });

    if (res.success) {
      conversations = res.conversations || [];
      messages = res.messages || [];
      renderChatList();
      lastPollTimestamp = new Date().toISOString();
    }
  } catch (e) {
    $('chatList').innerHTML =
      '<div style="padding:40px;text-align:center;color:var(--text-muted);font-size:14px;">Failed to load chats. Retrying...</div>';
    setTimeout(loadChats, 3000);
  }
}

function renderChatList() {
  const list = $('chatList');

  if (conversations.length === 0) {
    list.innerHTML = `<div style="padding:40px 20px;text-align:center;color:var(--text-muted);font-size:14px;line-height:1.6;">
      <div style="font-size:40px;margin-bottom:12px;opacity:0.3;">💬</div>
      No conversations yet.<br>Start chatting from the Kora mobile app!
    </div>`;
    return;
  }

  conversations.sort((a, b) => {
    const ta = new Date(a.lastMessageTimestamp || 0).getTime();
    const tb = new Date(b.lastMessageTimestamp || 0).getTime();
    return tb - ta;
  });

  list.innerHTML = conversations.map(c => `
    <div class="chat-item ${c.chatId === activeChatId ? 'active' : ''}" onclick="openChat('${escapeHtml(c.chatId)}')">
      <div class="avatar">${getAvatarHtml(c.avatarUrl, c.name)}</div>
      <div class="info">
        <div class="row1">
          <div class="name">${escapeHtml(c.name || c.chatId)}</div>
          <div class="time">${formatTime(c.lastMessageTimestamp)}</div>
        </div>
        <div class="row2">
          <div class="preview">${escapeHtml(c.lastMessageText || 'Tap to start chatting')}</div>
          ${c.unreadCount > 0 ? `<div class="badge">${c.unreadCount}</div>` : ''}
        </div>
      </div>
    </div>
  `).join('');
}

function filterChats() {
  const query = $('searchInput').value.toLowerCase().trim();
  document.querySelectorAll('.chat-item').forEach(item => {
    const name = item.querySelector('.name').textContent.toLowerCase();
    const preview = item.querySelector('.preview')?.textContent.toLowerCase() || '';
    item.style.display = (name.includes(query) || preview.includes(query)) ? '' : 'none';
  });
}

function openChat(chatId) {
  activeChatId = chatId;
  const conv = conversations.find(c => c.chatId === chatId);
  if (!conv) return;

  conv.unreadCount = 0;
  renderChatList();

  $('emptyChat').style.display = 'none';
  $('chatContent').style.display = 'flex';
  document.body.classList.add('mobile-chat-open');

  $('chatAvatar').innerHTML = getAvatarHtml(conv.avatarUrl, conv.name);
  $('chatName').textContent = conv.name || chatId;
  $('chatStatus').textContent = conv.isOnline ? 'online' : '';

  activeChatMessages = messages.filter(m => m.chatId === chatId);
  renderMessages();
  $('msgInput').focus();
}

function closeChatMobile() {
  document.body.classList.remove('mobile-chat-open');
}

function renderMessages() {
  const container = $('messages');

  let html = `
    <div class="e2ee-banner">
      <svg viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6z"/></svg>
      Messages are end-to-end encrypted
    </div>
  `;

  if (activeChatMessages.length === 0) {
    html += `<div style="padding:40px;text-align:center;color:var(--text-muted);font-size:13px;">No messages yet. Say hello! 👋</div>`;
    container.innerHTML = html;
    return;
  }

  let lastDate = '';
  activeChatMessages.forEach(m => {
    const msgDate = formatDateSeparator(m.timestamp);
    if (msgDate && msgDate !== lastDate) {
      html += `<div class="msg-date-sep">${msgDate}</div>`;
      lastDate = msgDate;
    }

    const isOutgoing = m.isMe;
    let tickHtml = '';
    if (isOutgoing) {
      if (m.isSeen) tickHtml = '<span class="ticks seen">✓✓</span>';
      else if (m.status === 'delivered') tickHtml = '<span class="ticks delivered">✓✓</span>';
      else tickHtml = '<span class="ticks sent">✓</span>';
    }

    let replyHtml = '';
    if (m.replyToText) {
      replyHtml = `<div class="msg-reply"><span class="reply-name">${escapeHtml(m.replyToName || '')}</span><span class="reply-text">${escapeHtml(m.replyToText)}</span></div>`;
    }

    let contentHtml = '';
    if (m.type === 'voice') {
      const dur = m.voiceDuration ? `${Math.floor(m.voiceDuration)}s` : '';
      contentHtml = `<div class="msg-voice">🎤 Voice note ${dur}</div>`;
    } else if (m.actionType) {
      contentHtml = `<div class="msg-action">${escapeHtml(m.actionLabel || m.actionType)}</div>`;
    } else {
      contentHtml = escapeHtml(m.text);
    }

    html += `
      <div class="msg ${isOutgoing ? 'outgoing' : 'incoming'}" data-id="${escapeHtml(m.messageId)}">
        ${replyHtml}
        <div class="msg-content">${contentHtml}</div>
        <div class="msg-time">${formatTime(m.timestamp)} ${tickHtml}</div>
      </div>
    `;
  });

  container.innerHTML = html;
  container.scrollTop = container.scrollHeight;
}

async function sendMessage() {
  const input = $('msgInput');
  const text = input.value.trim();
  if (!text || !activeChatId) return;

  input.value = '';

  const conv = conversations.find(c => c.chatId === activeChatId);
  if (!conv) return;

  const msgId = 'web_' + Date.now() + '_' + Math.random().toString(36).substr(2, 8);
  const now = new Date().toISOString();

  const newMsg = {
    chatId: activeChatId,
    messageId: msgId,
    text: text,
    timestamp: now,
    isMe: true,
    type: 'text',
    status: 'sent',
    isSeen: false,
    isStarred: false,
  };
  activeChatMessages.push(newMsg);
  messages.push(newMsg);
  renderMessages();

  conv.lastMessageText = text;
  conv.lastMessageTimestamp = now;
  renderChatList();

  try {
    await api(KORA_CONFIG.CHAT_SYNC_URL, {
      action: 'sync',
      userEmail: currentUser.email,
      recipientEmail: conv.recipientEmail || '',
      recipientName: conv.name || '',
      senderName: currentUser.fullName || currentUser.email,
      messages: [newMsg],
      conversations: [{
        chatId: activeChatId,
        name: conv.name || activeChatId,
        avatarUrl: conv.avatarUrl || '',
        lastMessageText: text,
        lastMessageTimestamp: now,
        lastMessageType: 'text',
        unreadCount: 0,
      }],
    });
  } catch (e) {
    showToast('Failed to send message');
  }
}

function showToast(msg) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => { t.style.opacity = '0'; setTimeout(() => t.remove(), 300); }, 2500);
}

function startMessagePolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = setInterval(pollMessages, KORA_CONFIG.POLL_INTERVAL);
}

async function pollMessages() {
  if (!currentUser) return;
  try {
    const res = await api(KORA_CONFIG.CHAT_SYNC_URL, {
      action: 'fetchNew',
      userEmail: currentUser.email,
      sinceTimestamp: lastPollTimestamp,
    });

    if (res.success) {
      lastPollTimestamp = new Date().toISOString();
      let changed = false;

      if (res.conversations && res.conversations.length > 0) {
        res.conversations.forEach(nc => {
          const idx = conversations.findIndex(c => c.chatId === nc.chatId);
          if (idx >= 0) conversations[idx] = { ...conversations[idx], ...nc };
          else conversations.push(nc);
        });
        changed = true;
      }

      if (res.messages && res.messages.length > 0) {
        res.messages.forEach(nm => {
          const exists = messages.find(m => m.messageId === nm.messageId);
          if (!exists) {
            messages.push(nm);
            if (nm.chatId === activeChatId) activeChatMessages.push(nm);
            changed = true;
          }
        });
      }

      if (changed) {
        renderChatList();
        if (activeChatId) renderMessages();
      }
    }
  } catch (e) { /* silent retry */ }
}

// ════════════════════════════════════════════════════════
// QR LOGIN (WhatsApp/Telegram-style device pairing)
// ════════════════════════════════════════════════════════
let qrPollTimer = null;
let qrCurrentToken = null;

function showQrScreen() {
  $('loginScreen').style.display = 'none';
  $('qrScreen').style.display = 'flex';
  requestQrCode();
}

function showLoginFromQr() {
  stopQrPolling();
  $('qrScreen').style.display = 'none';
  $('loginScreen').style.display = 'flex';
}

function stopQrPolling() {
  if (qrPollTimer) { clearInterval(qrPollTimer); qrPollTimer = null; }
}

async function requestQrCode() {
  $('qrImage').style.display = 'none';
  $('qrExpired').style.display = 'none';
  $('qrLoading').style.display = 'block';
  $('qrLoading').textContent = 'Generating code…';

  try {
    const res = await api(KORA_CONFIG.WEB_PAIR_URL, { action: 'requestPair' });
    if (!res.success) throw new Error(res.error || 'Failed to generate code');

    qrCurrentToken = res.pairingToken;
    const qrImgUrl = `https://api.qrserver.com/v1/create-qr-code/?size=380x380&margin=0&color=8B5CF6&data=${encodeURIComponent(res.qrData)}`;

    $('qrImage').onload = () => {
      $('qrLoading').style.display = 'none';
      $('qrImage').style.display = 'block';
    };
    $('qrImage').src = qrImgUrl;

    startQrPolling(res.ttlSeconds || 120);
  } catch (e) {
    $('qrLoading').textContent = 'Unable to generate code. Please try again.';
  }
}

function startQrPolling(ttlSeconds) {
  stopQrPolling();
  const deadline = Date.now() + ttlSeconds * 1000;

  qrPollTimer = setInterval(async () => {
    if (Date.now() > deadline) {
      stopQrPolling();
      $('qrImage').style.display = 'none';
      $('qrExpired').style.display = 'flex';
      return;
    }
    if (!qrCurrentToken) return;

    try {
      const res = await api(KORA_CONFIG.WEB_PAIR_URL, { action: 'pollPair', token: qrCurrentToken });
      if (!res.success) return;

      if (res.status === 'accepted' && res.user) {
        stopQrPolling();
        currentUser = res.user;
        saveSession();
        showApp();
      } else if (res.status === 'expired') {
        stopQrPolling();
        $('qrImage').style.display = 'none';
        $('qrExpired').style.display = 'flex';
      }
    } catch (e) { /* silent retry */ }
  }, 2500);
}

// ════════════════════════════════════════════════════════
// AUTH BACKGROUND THEME TOGGLE (cosmetic, per-browser)
// ════════════════════════════════════════════════════════
function initAuthThemeToggle() {
  const KEY = 'kora_web_auth_theme';
  const apply = (dark) => {
    document.documentElement.classList.toggle('auth-dark', dark);
  };
  apply(localStorage.getItem(KEY) === 'dark');

  const btn = $('themeToggleBtn');
  if (btn) {
    btn.addEventListener('click', () => {
      const isDark = document.documentElement.classList.toggle('auth-dark');
      localStorage.setItem(KEY, isDark ? 'dark' : 'light');
    });
  }
}

// ════════════════════════════════════════════════════════
// INIT
// ════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  const saved = loadSession();
  if (saved) {
    currentUser = saved;
    showApp();
  } else {
    $('loginScreen').style.display = 'flex';
  }

  $('loginBtn').addEventListener('click', handleLogin);
  $('loginPassword').addEventListener('keydown', (e) => { if (e.key === 'Enter') handleLogin(); });

  $('showQrBtn').addEventListener('click', (e) => { e.preventDefault(); showQrScreen(); });
  $('showEmailBtn').addEventListener('click', (e) => { e.preventDefault(); showLoginFromQr(); });
  $('qrBackBtn').addEventListener('click', showLoginFromQr);
  $('qrRefreshBtn').addEventListener('click', requestQrCode);
  initAuthThemeToggle();

  // Verification code inputs — auto-advance + auto-verify
  for (let i = 1; i <= 6; i++) {
    const input = $(`verifyCode${i}`);
    if (!input) continue;
    input.addEventListener('input', (e) => {
      if (e.target.value.length === 1 && i < 6) $(`verifyCode${i + 1}`).focus();
      if (i === 6 && e.target.value.length === 1) {
        const code = ['verifyCode1','verifyCode2','verifyCode3','verifyCode4','verifyCode5','verifyCode6']
          .map(id => $(id).value).join('');
        if (code.length === 6) handleVerify();
      }
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && !e.target.value && i > 1) $(`verifyCode${i - 1}`).focus();
    });
    input.addEventListener('paste', (e) => {
      e.preventDefault();
      const pasted = (e.clipboardData || window.clipboardData).getData('text').replace(/\D/g, '');
      for (let j = 0; j < 6 && j < pasted.length; j++) $(`verifyCode${j + 1}`).value = pasted[j];
      if (pasted.length >= 6) handleVerify();
      else if (pasted.length > 0) $(`verifyCode${Math.min(pasted.length, 6)}`).focus();
    });
  }

  $('verifyBtn').addEventListener('click', handleVerify);
  $('verifyBack').addEventListener('click', backToLogin);

  $('searchInput').addEventListener('input', filterChats);

  $('msgSendBtn').addEventListener('click', sendMessage);
  $('msgInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });

  $('chatBackBtn').addEventListener('click', closeChatMobile);
  $('logoutBtn').addEventListener('click', () => { if (confirm('Log out of Kora Web?')) logout(); });
  $('newChatBtn').addEventListener('click', () => showToast('New chat coming soon!'));
});
