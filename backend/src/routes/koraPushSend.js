const express = require('express');
const { GoogleAuth } = require('google-auth-library');
const User = require('../models/User');

const router = express.Router();

// Kora Push Send — FCM HTTP v1 API (legacy server-key API was retired by Google).
// Uses the service account in FCM_SERVICE_ACCOUNT_JSON to mint OAuth2 tokens.

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

let cachedAuth = null;
let cachedToken = null;
let tokenExpiry = 0;

function getServiceAccount() {
  const raw = process.env.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error('[koraPushSend] FCM_SERVICE_ACCOUNT_JSON is not valid JSON');
    return null;
  }
}

async function getAccessToken(projectId) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && tokenExpiry - now > 60) {
    return cachedToken;
  }

  if (!cachedAuth) {
    const serviceAccount = getServiceAccount();
    if (!serviceAccount) return null;
    cachedAuth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: (serviceAccount.private_key || '').replace(/\\n/g, '\n'),
      },
      scopes: [FCM_SCOPE],
    });
  }

  const client = await cachedAuth.getClient();
  const tokenRes = await client.getAccessToken();
  if (!tokenRes || !tokenRes.token) {
    throw new Error('Failed to obtain FCM access token');
  }
  cachedToken = tokenRes.token;
  tokenExpiry = (client.credentials && client.credentials.expiry_date)
    ? Math.floor(client.credentials.expiry_date / 1000)
    : now + 3000;
  return cachedToken;
}

router.all('/', async (req, res) => {
  const params = { ...(req.query || {}), ...(req.body || {}) };
  const {
    email,
    type,
    senderName,
    messageText,
    chatId,
    isGroup,
    groupName,
    isVideo,
    callId,
  } = params;

  if (!email || !type) {
    return res.json({ ok: false, error: 'email and type are required' });
  }

  try {
    const normalizedEmail = String(email).toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.json({ ok: false, error: 'User not found' });
    }

    const fcmToken = user.fcmToken;
    if (!fcmToken) {
      return res.json({ ok: false, error: 'User has no FCM token registered' });
    }

    const serviceAccount = getServiceAccount();
    if (!serviceAccount) {
      console.warn('[koraPushSend] FCM_SERVICE_ACCOUNT_JSON not configured — push not sent');
      return res.json({ ok: false, error: 'FCM not configured' });
    }
    const projectId = serviceAccount.project_id;

    // Build the FCM v1 message payload (data-only message, same fields the app handles)
    const data = {
      type: type || 'message',
      sender_name: senderName || 'Kora',
      message: messageText || '',
      chat_id: chatId || '',
      is_group: isGroup ? 'true' : 'false',
      is_video: isVideo ? 'true' : 'false',
      timestamp: Date.now().toString(),
    };

    if (groupName) {
      data.group_name = groupName;
    }
    if (callId) {
      data.call_id = callId;
    }

    const message = {
      token: fcmToken,
      data,
      android: {
        priority: type === 'call' ? 'high' : 'normal',
      },
    };

    const accessToken = await getAccessToken(projectId);

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message }),
      }
    );

    if (response.ok) {
      return res.json({ ok: true, message: 'Push sent' });
    } else {
      const errorText = await response.text();
      console.error('[koraPushSend] FCM error:', errorText);
      return res.json({ ok: false, error: errorText });
    }
  } catch (error) {
    console.error('[koraPushSend] Error:', error.message || error);
    return res.json({ ok: false, error: error.message || String(error) });
  }
});

module.exports = router;
