const express = require('express');
const ChatMessage = require('../models/ChatMessage');
const Conversation = require('../models/Conversation');

const router = express.Router();

// Kora Service Notification — 1:1 mirror of the Base44
// koraServiceNotification function. Telegram-style service messages
// (like 777000) delivered into the "Kora Notifications" system chat.
//
// Deduplication window: 15 minutes (matching Telegram's behavior).
const DEDUP_WINDOW_MS = 15 * 60 * 1000;

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action } = body;

  try {
    // ── PUSH SERVICE NOTIFICATION ──────────────────────
    // Stores a service notification for a user. The client polls
    // for new notifications and displays them as either a popup
    // (if popup=true) or a message in the Kora Notifications chat.
    if (action === 'push') {
      const { email, type, message, popup, mediaUrl } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });
      if (!message) return res.json({ success: false, error: 'Message is required' });

      const lowerEmail = String(email).toLowerCase().trim();

      // Check if a notification of the same type was already sent recently (dedup)
      const recent = await ChatMessage.find({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      })
        .sort('-timestamp')
        .limit(100);

      if (recent && recent.length > 0) {
        const fifteenMinAgo = Date.now() - DEDUP_WINDOW_MS;
        for (const msg of recent) {
          const msgType = msg.actionType ?? '';
          const msgTime = new Date(msg.timestamp ?? Date.now()).getTime();
          if (msgType === type && msgTime > fifteenMinAgo) {
            // Duplicate within 15 minutes — skip
            return res.json({
              success: true,
              deduplicated: true,
              message: 'Notification of this type was recently sent',
            });
          }
        }
      }

      // Store as a ChatMessage in the Kora Notifications system chat
      const now = new Date().toISOString();
      const notifId = 'sn-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8);

      await ChatMessage.create({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        messageId: notifId,
        text: message,
        type: 'service',
        isAi: false,
        isMe: false,
        isSeen: false,
        isStarred: false,
        isWebSearch: false,
        timestamp: now,
        lastMessageText: message,
        lastMessageTimestamp: now,
        lastMessageType: 'service',
        actionType: type,
        actionLabel: popup ? 'popup' : 'message',
        status: 'sent',
        reaction: '',
        replyToId: '',
        replyToName: '',
        replyToText: '',
      });

      // Also create or update the Kora Notifications conversation
      const existingConv = await Conversation.findOne({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
      });

      if (existingConv) {
        existingConv.lastMessageText = message;
        existingConv.lastMessageTimestamp = now;
        existingConv.lastMessageType = 'service';
        existingConv.unreadCount = (existingConv.unreadCount ?? 0) + 1;
        existingConv.isOnline = false;
        // Self-heal the official badge — some legacy records (and the
        // koraAuth login-code path) were created with badge 0.
        existingConv.badge = 1;
        await existingConv.save();
      } else {
        await Conversation.create({
          userEmail: lowerEmail,
          chatId: 'kora_notifications',
          name: 'Kora Notifications',
          avatarUrl: '',
          avatarAsset: 'assets/images/kora_notifications_avatar.webp',
          badge: 1, // official purple (KoraBadgeType.officialPurple)
          isOnline: false,
          lastMessageText: message,
          lastMessageTimestamp: now,
          lastMessageType: 'service',
          unreadCount: 1,
          recipientEmail: 'system@kora.app',
        });
      }

      return res.json({
        success: true,
        notificationId: notifId,
        popup: popup === true,
        message: 'Service notification delivered',
      });
    }

    // ── POLL FOR NEW NOTIFICATIONS ─────────────────────
    if (action === 'poll') {
      const { email, lastSeenTimestamp } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();

      const messages = await ChatMessage.find({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      });

      const since = lastSeenTimestamp ? new Date(lastSeenTimestamp).getTime() : 0;
      const newNotifs = (messages || [])
        .filter((m) => new Date(m.timestamp ?? 0).getTime() > since)
        .map((m) => ({
          id: m._id.toString(),
          messageId: m.messageId ?? '',
          type: m.actionType ?? '',
          text: m.text ?? '',
          popup: (m.actionLabel) === 'popup',
          timestamp: m.timestamp ?? '',
          isSeen: m.isSeen ?? false,
        }))
        .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

      return res.json({
        success: true,
        notifications: newNotifs,
        count: newNotifs.length,
      });
    }

    // ── MARK NOTIFICATIONS AS SEEN ──────────────────────
    if (action === 'markSeen') {
      const { email, notificationIds } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();

      if (notificationIds && Array.isArray(notificationIds) && notificationIds.length > 0) {
        for (const nid of notificationIds) {
          try {
            await ChatMessage.updateOne(
              { userEmail: lowerEmail, _id: nid },
              { $set: { isSeen: true } }
            );
          } catch (_) {}
        }
      } else {
        // Empty list = mark ALL service messages as seen (the client
        // calls this when the user opens the Kora Notifications chat,
        // mirroring Telegram's read-on-open behavior for 777000).
        await ChatMessage.updateMany(
          { userEmail: lowerEmail, chatId: 'kora_notifications', type: 'service' },
          { $set: { isSeen: true } }
        );
      }

      // Also reset the unread count on the conversation
      await Conversation.updateOne(
        { userEmail: lowerEmail, chatId: 'kora_notifications' },
        { $set: { unreadCount: 0 } }
      );

      return res.json({ success: true, message: 'Marked as seen' });
    }

    // ── GET NOTIFICATION HISTORY ────────────────────────
    if (action === 'history') {
      const { email, limit, skip } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();
      const maxLimit = Math.min(limit ?? 50, 100);
      const offset = skip ?? 0;

      const messages = await ChatMessage.find({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      });

      const sorted = (messages || [])
        .sort(
          (a, b) =>
            new Date(b.timestamp ?? 0).getTime() - new Date(a.timestamp ?? 0).getTime()
        )
        .slice(offset, offset + maxLimit)
        .map((m) => ({
          id: m._id.toString(),
          messageId: m.messageId ?? '',
          type: m.actionType ?? '',
          text: m.text ?? '',
          popup: (m.actionLabel) === 'popup',
          timestamp: m.timestamp ?? '',
          isSeen: m.isSeen ?? false,
        }));

      return res.json({
        success: true,
        notifications: sorted,
        hasMore: (messages?.length ?? 0) > offset + maxLimit,
      });
    }

    return res.json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
