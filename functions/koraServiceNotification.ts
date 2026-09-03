import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Deduplication window: 15 minutes (matching Telegram's behavior).
const DEDUP_WINDOW_MS = 15 * 60 * 1000;

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── PUSH SERVICE NOTIFICATION ──────────────────────
    // Stores a service notification for a user. The client polls
    // for new notifications and displays them as either a popup
    // (if popup=true) or a message in the Kora Notifications chat.
    //
    // Parameters:
    //   email    — recipient user email
    //   type     — notification type string (for dedup, e.g. "security_login")
    //   message  — notification text (supports entities for formatting)
    //   popup    — if true, show as an immediate alert dialog
    //   mediaUrl — optional media attachment
    if (action === 'push') {
      const { email, type, message, popup, mediaUrl } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });
      if (!message) return jsonResponse({ success: false, error: 'Message is required' });

      const lowerEmail = email.toLowerCase().trim();

      // Check if a notification of the same type was already sent recently (dedup)
      const recent = await db.entities.ChatMessage.filter({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      }, '-timestamp', 100);

      if (recent && recent.length > 0) {
        const fifteenMinAgo = Date.now() - DEDUP_WINDOW_MS;
        for (const msg of recent) {
          const msgType = msg.data?.actionType ?? msg.actionType ?? '';
          const msgTime = new Date(msg.data?.timestamp ?? msg.timestamp ?? Date.now()).getTime();
          if (msgType === type && msgTime > fifteenMinAgo) {
            // Duplicate within 15 minutes — skip
            return jsonResponse({
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

      await db.entities.ChatMessage.create({
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
      const existingConv = await db.entities.Conversation.filter({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
      });

      if (existingConv && existingConv.length > 0) {
        await db.entities.Conversation.update(existingConv[0].id, {
          lastMessageText: message,
          lastMessageTimestamp: now,
          lastMessageType: 'service',
          unreadCount: (existingConv[0].data?.unreadCount ?? 0) + 1,
          isOnline: false,
          // Self-heal the official badge — some legacy records (and the
          // koraAuth login-code path) were created with badge 0.
          badge: 1,
        });
      } else {
        await db.entities.Conversation.create({
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

      return jsonResponse({
        success: true,
        notificationId: notifId,
        popup: popup === true,
        message: 'Service notification delivered',
      });
    }

    // ── POLL FOR NEW NOTIFICATIONS ─────────────────────
    // The client calls this periodically to fetch new service
    // notifications. Returns unseen notifications sorted by time.
    if (action === 'poll') {
      const { email, lastSeenTimestamp } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();

      // Get all service notifications from the Kora Notifications chat
      const messages = await db.entities.ChatMessage.filter({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      });

      // Filter to only unseen or newer than lastSeenTimestamp
      const since = lastSeenTimestamp ? new Date(lastSeenTimestamp).getTime() : 0;
      const newNotifs = (messages || [])
        .filter((m: any) => {
          const msgTime = new Date(m.data?.timestamp ?? m.timestamp ?? 0).getTime();
          return msgTime > since;
        })
        .map((m: any) => ({
          id: m.id,
          messageId: m.data?.messageId ?? m.messageId ?? '',
          type: m.data?.actionType ?? m.actionType ?? '',
          text: m.data?.text ?? m.text ?? '',
          popup: (m.data?.actionLabel ?? m.actionLabel) === 'popup',
          timestamp: m.data?.timestamp ?? m.timestamp ?? '',
          isSeen: m.data?.isSeen ?? m.isSeen ?? false,
        }))
        .sort((a: any, b: any) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

      return jsonResponse({
        success: true,
        notifications: newNotifs,
        count: newNotifs.length,
      });
    }

    // ── MARK NOTIFICATIONS AS SEEN ──────────────────────
    if (action === 'markSeen') {
      const { email, notificationIds } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();

      if (notificationIds && Array.isArray(notificationIds) && notificationIds.length > 0) {
        for (const nid of notificationIds) {
          try {
            const msgs = await db.entities.ChatMessage.filter({
              userEmail: lowerEmail,
              id: nid,
            });
            if (msgs && msgs.length > 0) {
              await db.entities.ChatMessage.update(msgs[0].id, { isSeen: true });
            }
          } catch (_) {}
        }
      } else {
        // Empty list = mark ALL service messages as seen (the client
        // calls this when the user opens the Kora Notifications chat,
        // mirroring Telegram's read-on-open behavior for 777000).
        let skip = 0;
        let hasMore = true;
        while (hasMore) {
          const batch = await db.entities.ChatMessage.filter({
            userEmail: lowerEmail,
            chatId: 'kora_notifications',
            type: 'service',
          }, undefined, 500, skip);
          if (batch && batch.length > 0) {
            for (const msg of batch) {
              if (!(msg.data?.isSeen ?? msg.isSeen ?? false)) {
                await db.entities.ChatMessage.update(msg.id, { isSeen: true });
              }
            }
            skip += batch.length;
          }
          hasMore = batch && batch.length === 500;
        }
      }

      // Also reset the unread count on the conversation
      const convs = await db.entities.Conversation.filter({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
      });
      if (convs && convs.length > 0) {
        await db.entities.Conversation.update(convs[0].id, { unreadCount: 0 });
      }

      return jsonResponse({ success: true, message: 'Marked as seen' });
    }

    // ── GET NOTIFICATION HISTORY ────────────────────────
    if (action === 'history') {
      const { email, limit, skip } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();
      const maxLimit = Math.min(limit ?? 50, 100);
      const offset = skip ?? 0;

      const messages = await db.entities.ChatMessage.filter({
        userEmail: lowerEmail,
        chatId: 'kora_notifications',
        type: 'service',
      });

      const sorted = (messages || [])
        .sort((a: any, b: any) => {
          const aTime = new Date(a.data?.timestamp ?? a.timestamp ?? 0).getTime();
          const bTime = new Date(b.data?.timestamp ?? b.timestamp ?? 0).getTime();
          return bTime - aTime;
        })
        .slice(offset, offset + maxLimit)
        .map((m: any) => ({
          id: m.id,
          messageId: m.data?.messageId ?? m.messageId ?? '',
          type: m.data?.actionType ?? m.actionType ?? '',
          text: m.data?.text ?? m.text ?? '',
          popup: (m.data?.actionLabel ?? m.actionLabel) === 'popup',
          timestamp: m.data?.timestamp ?? m.timestamp ?? '',
          isSeen: m.data?.isSeen ?? m.isSeen ?? false,
        }));

      return jsonResponse({
        success: true,
        notifications: sorted,
        hasMore: (messages?.length ?? 0) > offset + maxLimit,
      });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
