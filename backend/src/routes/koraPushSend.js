const express = require('express');
const User = require('../models/User');

const router = express.Router();

// Kora Push Send — 1:1 mirror of the Base44 koraPushSend function.
// Sends an FCM push notification to a user.

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

    // Build the FCM payload
    const payload = {
      token: fcmToken,
      data: {
        type: type || 'message',
        sender_name: senderName || 'Kora',
        message: messageText || '',
        chat_id: chatId || '',
        is_group: isGroup ? 'true' : 'false',
        is_video: isVideo ? 'true' : 'false',
        timestamp: Date.now().toString(),
      },
      android: {
        priority: type === 'call' ? 'high' : 'normal',
      },
    };

    if (groupName) {
      payload.data.group_name = groupName;
    }
    if (callId) {
      payload.data.call_id = callId;
    }

    const serverKey = process.env.FCM_SERVER_KEY;
    if (!serverKey) {
      console.warn('[koraPushSend] FCM_SERVER_KEY not configured — push not sent');
      return res.json({ ok: false, error: 'FCM_SERVER_KEY not configured' });
    }

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${serverKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: fcmToken,
        data: payload.data,
        priority: type === 'call' ? 'high' : 'normal',
      }),
    });

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
