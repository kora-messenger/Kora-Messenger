import { base44 } from '@base44/sdk';

/**
 * Sends an FCM push notification to a user.
 * Called by koraChatSync when a new message is detected for an offline user.
 *
 * Body: {
 *   email: string,       // recipient email
 *   type: string,        // message | group_message | call | missed_call | status | channel_update
 *   senderName: string,  // who sent the message
 *   messageText: string, // message preview
 *   chatId: string,      // chat identifier
 *   isGroup?: boolean,
 *   groupName?: string,
 *   isVideo?: boolean,   // for call notifications
 *   callId?: string,     // for call notifications
 * }
 */
export default async function(req: any) {
  const { email, type, senderName, messageText, chatId,
          isGroup, groupName, isVideo, callId } = req.body || {};

  if (!email || !type) {
    return { ok: false, error: 'email and type are required' };
  }

  try {
    // Find the user's FCM token
    const users = await base44.entities.KoraUser.list({
      filter: { email }
    });

    if (users.length === 0) {
      return { ok: false, error: 'User not found' };
    }

    const user = users[0];
    const fcmToken = user.fcmToken;

    if (!fcmToken) {
      return { ok: false, error: 'User has no FCM token registered' };
    }

    // Build the FCM payload
    const payload: any = {
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

    // Send via Firebase Cloud Messaging HTTP v1 API
    // Requires FCM_SERVER_KEY or Firebase service account
    const serverKey = process.env.FCM_SERVER_KEY;

    if (!serverKey) {
      console.warn('[koraPushSend] FCM_SERVER_KEY not configured — push not sent');
      return { ok: false, error: 'FCM_SERVER_KEY not configured' };
    }

    // Use legacy FCM HTTP API (simplest — works with server key)
    // Note: migrate to v1 API with OAuth2 when available
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
      return { ok: true, message: 'Push sent' };
    } else {
      const errorText = await response.text();
      console.error('[koraPushSend] FCM error:', errorText);
      return { ok: false, error: errorText };
    }
  } catch (error: any) {
    console.error('[koraPushSend] Error:', error.message);
    return { ok: false, error: error.message };
  }
}
