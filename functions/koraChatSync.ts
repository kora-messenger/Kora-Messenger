/**
 * Kora Chat Sync — Backend persistence for all chats and messages.
 *
 * This function handles actions:
 * 1. "sync" — Save new/updated messages + conversations to the database
 * 2. "fetch" — Load all conversations + messages for a user (on login/reinstall)
 * 3. "fetchNew" — Load conversations + messages updated after a timestamp (for polling)
 * 4. "backup" — Export all chat data for the user (for Chat Backup screen)
 * 5. "clearChat" — Delete all messages for a specific chat
 *
 * Messages and conversations are scoped by userEmail (row-level security).
 * Even if the user deletes and reinstalls the app, logging in with the same
 * email restores all chats.
 *
 * Entity: Conversation, ChatMessage
 *
 * NOTE: The Base44 SDK entity API uses POSITIONAL params:
 *   .filter(query, sort, limit, skip, fields)
 *   .list(sort, limit, skip, fields)
 * .list() has NO filter argument — passing an object as the first param
 * silently returns zero records. Always use .filter(query) for reads.
 */

import { createClientFromRequest } from "npm:@base44/sdk@0.8.31";

// Badge derivation — see KoraBadgeType in lib/models/chat_models.dart.
// Owner accounts get the purple "official" badge — must stay in sync
// with kOwnerEmails in lib/theme/chat_theme_provider.dart.
const OWNER_EMAILS = new Set([
  'goodluckijezie9@gmail.com',
  'ijeziegoodluck7@gmail.com',
  'ijeziegoodluck4@gmail.com',
  'ijeziegoodluck96@gmail.com',
]);

// Badge enum mirrors KoraBadgeType in lib/models/chat_models.dart:
// 0 = none, 1 = officialPurple (owner), 2 = premiumBlue (premium).
async function deriveBadgeFor(db: any, email: any): Promise<number> {
  try {
    const normalized = String(email ?? '').toLowerCase().trim();
    if (!normalized) return 0;
    if (OWNER_EMAILS.has(normalized)) return 1;
    const users = await db.entities.KoraUser.filter(
      { email: normalized },
      undefined,
      1,
    );
    if (!users || users.length === 0) return -1; // user not found
    const u = users[0];
    const isPremium = (u.data?.isPremium ?? u.isPremium ?? false) === true;
    return isPremium ? 2 : 0;
  } catch (_) {
    return 0;
  }
}

// Helper functions to map entity records to standard response schema
function mapConversation(c: any) {
  return {
    chatId: c.chatId,
    recipientEmail: c.recipientEmail,
    name: c.name,
    avatarAsset: c.avatarAsset,
    avatarUrl: c.avatarUrl,
    badge: c.badge,
    isOnline: c.isOnline,
    lastMessageText: c.lastMessageText,
    lastMessageTimestamp: c.lastMessageTimestamp,
    lastMessageType: c.lastMessageType,
    lastVoiceDuration: c.lastVoiceDuration,
    unreadCount: c.unreadCount,
  };
}

function mapMessage(m: any) {
  return {
    chatId: m.chatId,
    messageId: m.messageId,
    text: m.text,
    timestamp: m.timestamp,
    isMe: m.isMe,
    type: m.type,
    status: m.status,
    replyToId: m.replyToId,
    replyToText: m.replyToText,
    replyToName: m.replyToName,
    reaction: m.reaction,
    voiceDuration: m.voiceDuration,
    voiceFilePath: m.voiceFilePath,
    voiceFileUrl: m.voiceFileUrl,
    voiceTranscript: m.voiceTranscript,
    mediaUrl: m.mediaUrl,
    mediaCaption: m.mediaCaption,
    isViewOnce: m.isViewOnce,
    mediaWidth: m.mediaWidth,
    mediaHeight: m.mediaHeight,
    mediaDuration: m.mediaDuration,
    isAi: m.isAi,
    isWebSearch: m.isWebSearch,
    isSeen: m.isSeen,
    isStarred: m.isStarred,
    actionLabel: m.actionLabel,
    actionType: m.actionType,
  };
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { action, userEmail, recipientEmail, recipientName, senderName, messages, conversations, chatId, sinceTimestamp } = body;

    if (!userEmail) {
      return new Response(
        JSON.stringify({ error: "userEmail is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const base44 = createClientFromRequest(req);
    const db = base44.asServiceRole;

    // ── ACTION: SYNC ──────────────────────────────────────────
    // Save messages and conversations to the database.
    // Called by the app after every message send/receive.
    if (action === "sync") {
      let savedMessages = 0;
      let savedConversations = 0;

      // Save messages (batch)
      if (messages && Array.isArray(messages) && messages.length > 0) {
        for (const msg of messages) {
          // Check if message already exists
          const existing = await db.entities.ChatMessage.filter(
            { userEmail: userEmail, messageId: msg.messageId },
            undefined,
            1
          );

          if (existing && existing.length > 0) {
            // Update existing message (status, isSeen, etc.)
            await db.entities.ChatMessage.update(existing[0].id, {
              status: msg.status,
              isSeen: msg.isSeen,
              isStarred: msg.isStarred ?? false,
              reaction: msg.reaction,
              // Media fields may arrive later (upload finishes after send)
              ...(msg.mediaUrl !== undefined && msg.mediaUrl !== null && { mediaUrl: msg.mediaUrl }),
              ...(msg.voiceFileUrl !== undefined && msg.voiceFileUrl !== null && { voiceFileUrl: msg.voiceFileUrl }),
            });
          } else {
            // Create new message
            await db.entities.ChatMessage.create({
              userEmail: userEmail,
              chatId: msg.chatId,
              messageId: msg.messageId,
              text: msg.text || "",
              timestamp: msg.timestamp,
              isMe: msg.isMe ?? false,
              type: msg.type || "text",
              status: msg.status || "none",
              replyToId: msg.replyToId,
              replyToText: msg.replyToText,
              replyToName: msg.replyToName,
              reaction: msg.reaction,
              voiceDuration: msg.voiceDuration,
              voiceFilePath: msg.voiceFilePath,
              voiceFileUrl: msg.voiceFileUrl,
              voiceTranscript: msg.voiceTranscript,
              mediaUrl: msg.mediaUrl,
              mediaCaption: msg.mediaCaption,
              isViewOnce: msg.isViewOnce ?? false,
              mediaWidth: msg.mediaWidth,
              mediaHeight: msg.mediaHeight,
              mediaDuration: msg.mediaDuration,
              isAi: msg.isAi ?? false,
              isWebSearch: msg.isWebSearch ?? false,
              isSeen: msg.isSeen ?? false,
              isStarred: msg.isStarred ?? false,
              actionLabel: msg.actionLabel,
              actionType: msg.actionType,
            });
          }
          savedMessages++;
        }
      }

      // ── Cross-user delivery: copy messages to recipient's account ──
      let deliveredNew = false;
      if (recipientEmail && messages && Array.isArray(messages) && messages.length > 0) {
        for (const msg of messages) {
          // Use a different messageId for the recipient's copy
          const recipientMsgId = 'recv_' + msg.messageId;
          const recipientChatId = msg.chatId;

          // Check if recipient already has this message
          const recvExisting = await db.entities.ChatMessage.filter(
            { userEmail: recipientEmail, messageId: recipientMsgId },
            undefined,
            1
          );

          if (!recvExisting || recvExisting.length === 0) {
            await db.entities.ChatMessage.create({
              userEmail: recipientEmail,
              chatId: recipientChatId,
              messageId: recipientMsgId,
              text: msg.text || "",
              timestamp: msg.timestamp,
              isMe: false, // recipient sees it as incoming
              type: msg.type || "text",
              status: "none",
              replyToId: msg.replyToId,
              replyToText: msg.replyToText,
              replyToName: msg.replyToName,
              reaction: msg.reaction,
              voiceDuration: msg.voiceDuration,
              voiceFilePath: msg.voiceFilePath,
              voiceFileUrl: msg.voiceFileUrl,
              voiceTranscript: msg.voiceTranscript,
              mediaUrl: msg.mediaUrl,
              mediaCaption: msg.mediaCaption,
              isViewOnce: msg.isViewOnce ?? false,
              mediaWidth: msg.mediaWidth,
              mediaHeight: msg.mediaHeight,
              mediaDuration: msg.mediaDuration,
              isAi: msg.isAi ?? false,
              isWebSearch: msg.isWebSearch ?? false,
              isSeen: false,
              isStarred: false,
              actionLabel: msg.actionLabel,
              actionType: msg.actionType,
            });
            deliveredNew = true;
          }
        }

        // Also create/update a conversation for the recipient —
        // but only if a NEW message was actually delivered (avoid
        // incrementing unreadCount on re-syncs of the same message).
        if (recipientName && deliveredNew) {
          const lastMsg = messages[messages.length - 1];
          const recvConvExisting = await db.entities.Conversation.filter(
            { userEmail: recipientEmail, chatId: lastMsg.chatId },
            undefined,
            1
          );

          if (recvConvExisting && recvConvExisting.length > 0) {
            // Keep the badge fresh — the sender may have become premium
            // (or an owner) after this conversation was created.
            const senderBadge = Math.max(
              0,
              await deriveBadgeFor(db, userEmail),
            );
            await db.entities.Conversation.update(recvConvExisting[0].id, {
              recipientEmail: userEmail, // sender's email, so replies route back
              name: senderName || recvConvExisting[0].name,
              badge: senderBadge,
              lastMessageText: lastMsg.text || "",
              lastMessageTimestamp: lastMsg.timestamp,
              lastMessageType: lastMsg.type || "text",
              unreadCount: (recvConvExisting[0].unreadCount || 0) + 1,
            });
          } else {
            await db.entities.Conversation.create({
              userEmail: recipientEmail,
              recipientEmail: userEmail, // sender's email, so replies route back
              chatId: lastMsg.chatId,
              name: senderName || "Unknown",
              badge: await deriveBadgeFor(db, userEmail),
              isOnline: true,
              lastMessageText: lastMsg.text || "",
              lastMessageTimestamp: lastMsg.timestamp,
              lastMessageType: lastMsg.type || "text",
              unreadCount: 1,
            });
          }
        }
      }

      // Save/update conversations (batch)
      if (conversations && Array.isArray(conversations) && conversations.length > 0) {
        for (const conv of conversations) {
          const existing = await db.entities.Conversation.filter(
            { userEmail: userEmail, chatId: conv.chatId },
            undefined,
            1
          );

          if (existing && existing.length > 0) {
            // Update conversation metadata. If the client didn't know
            // the other user's badge, derive it from their profile so
            // badges propagate to every device. Never downgrade.
            const derivedBadge = await deriveBadgeFor(
              db,
              conv.recipientEmail ?? existing[0].recipientEmail,
            );
            // Authoritative when the recipient's profile was found
            // (also handles premium revocation); otherwise keep the
            // client's value (group chats / channels).
            const finalBadge = derivedBadge >= 0
              ? derivedBadge
              : (conv.badge ?? 0);
            await db.entities.Conversation.update(existing[0].id, {
              name: conv.name,
              avatarAsset: conv.avatarAsset,
              avatarUrl: conv.avatarUrl,
              badge: finalBadge,
              isOnline: conv.isOnline ?? false,
              lastMessageText: conv.lastMessageText,
              lastMessageTimestamp: conv.lastMessageTimestamp,
              lastMessageType: conv.lastMessageType,
              lastVoiceDuration: conv.lastVoiceDuration,
              unreadCount: conv.unreadCount ?? 0,
            });
          } else {
            // Create new conversation. Derive the other user's badge
            // from their profile when the client couldn't know it.
            const derivedBadge = await deriveBadgeFor(db, conv.recipientEmail);
            const finalBadge = derivedBadge >= 0
              ? derivedBadge
              : (conv.badge ?? 0);
            await db.entities.Conversation.create({
              userEmail: userEmail,
              chatId: conv.chatId,
              name: conv.name || conv.chatId,
              avatarAsset: conv.avatarAsset,
              avatarUrl: conv.avatarUrl,
              badge: finalBadge,
              isOnline: conv.isOnline ?? false,
              lastMessageText: conv.lastMessageText,
              lastMessageTimestamp: conv.lastMessageTimestamp,
              lastMessageType: conv.lastMessageType,
              lastVoiceDuration: conv.lastVoiceDuration,
              unreadCount: conv.unreadCount ?? 0,
            });
          }
          savedConversations++;
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          savedMessages,
          savedConversations,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── ACTION: FETCH ─────────────────────────────────────────
    // Load all conversations + messages for a user.
    // Called on login or app start to restore chats after reinstall.
    if (action === "fetch") {
      // Fetch all conversations
      const allConversations = [];
      let skipConv = 0;
      let hasMoreConv = true;
      while (hasMoreConv) {
        const batch = await db.entities.Conversation.filter(
          { userEmail: userEmail },
          "-lastMessageTimestamp",
          500,
          skipConv
        );
        if (batch && batch.length > 0) {
          allConversations.push(...batch);
          skipConv += batch.length;
        }
        hasMoreConv = batch && batch.length === 500;
      }

      // Fetch all messages
      const allMessages = [];
      let skipMsg = 0;
      let hasMoreMsg = true;
      while (hasMoreMsg) {
        const batch = await db.entities.ChatMessage.filter(
          { userEmail: userEmail },
          "timestamp",
          500,
          skipMsg
        );
        if (batch && batch.length > 0) {
          allMessages.push(...batch);
          skipMsg += batch.length;
        }
        hasMoreMsg = batch && batch.length === 500;
      }

      return new Response(
        JSON.stringify({
          success: true,
          conversations: allConversations.map(mapConversation),
          messages: allMessages.map(mapMessage),
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── ACTION: FETCH_NEW ─────────────────────────────────────
    // Fetch conversations + messages updated after sinceTimestamp.
    // Used for lightweight, efficient polling.
    if (action === "fetchNew") {
      // Build query for conversations updated after sinceTimestamp
      const convQuery: Record<string, any> = { userEmail: userEmail };
      if (sinceTimestamp) {
        convQuery.updated_date = { $gt: sinceTimestamp };
      }

      const allConversations: any[] = [];
      let skipConv = 0;
      let hasMoreConv = true;
      while (hasMoreConv) {
        const batch = await db.entities.Conversation.filter(
          convQuery,
          "-lastMessageTimestamp",
          500,
          skipConv
        );
        if (batch && batch.length > 0) {
          allConversations.push(...batch);
          skipConv += batch.length;
        }
        hasMoreConv = batch && batch.length === 500;
      }

      // Code filter in case base44 SDK filter needs in-memory verification
      let filteredConversations = allConversations;
      if (sinceTimestamp) {
        const sinceTime = new Date(sinceTimestamp).getTime();
        filteredConversations = allConversations.filter(c => {
          const rawDate = c.updated_date || c.lastMessageTimestamp;
          if (!rawDate) return true;
          const convTime = new Date(rawDate).getTime();
          return !isNaN(sinceTime) && !isNaN(convTime)
            ? convTime > sinceTime
            : rawDate > sinceTimestamp;
        });
      }

      // Build query for messages created/updated after sinceTimestamp
      const msgQuery: Record<string, any> = { userEmail: userEmail };
      if (sinceTimestamp) {
        msgQuery.timestamp = { $gt: sinceTimestamp };
      }

      const allMessages: any[] = [];
      let skipMsg = 0;
      let hasMoreMsg = true;
      while (hasMoreMsg) {
        const batch = await db.entities.ChatMessage.filter(
          msgQuery,
          "timestamp",
          500,
          skipMsg
        );
        if (batch && batch.length > 0) {
          allMessages.push(...batch);
          skipMsg += batch.length;
        }
        hasMoreMsg = batch && batch.length === 500;
      }

      // Code filter in case base44 SDK filter needs in-memory verification
      let filteredMessages = allMessages;
      if (sinceTimestamp) {
        const sinceTime = new Date(sinceTimestamp).getTime();
        filteredMessages = allMessages.filter(m => {
          if (!m.timestamp) return false;
          const msgTime = new Date(m.timestamp).getTime();
          return !isNaN(sinceTime) && !isNaN(msgTime)
            ? msgTime > sinceTime
            : m.timestamp > sinceTimestamp;
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          conversations: filteredConversations.map(mapConversation),
          messages: filteredMessages.map(mapMessage),
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── ACTION: BACKUP ────────────────────────────────────────
    // Export all chat data — used by the Chat Backup screen.
    if (action === "backup") {
      const allConversations = [];
      let skipConv = 0;
      let hasMoreConv = true;
      while (hasMoreConv) {
        const batch = await db.entities.Conversation.filter(
          { userEmail: userEmail },
          undefined,
          500,
          skipConv
        );
        if (batch && batch.length > 0) {
          allConversations.push(...batch);
          skipConv += batch.length;
        }
        hasMoreConv = batch && batch.length === 500;
      }

      const allMessages = [];
      let skipMsg = 0;
      let hasMoreMsg = true;
      while (hasMoreMsg) {
        const batch = await db.entities.ChatMessage.filter(
          { userEmail: userEmail },
          undefined,
          500,
          skipMsg
        );
        if (batch && batch.length > 0) {
          allMessages.push(...batch);
          skipMsg += batch.length;
        }
        hasMoreMsg = batch && batch.length === 500;
      }

      return new Response(
        JSON.stringify({
          success: true,
          backupDate: new Date().toISOString(),
          totalConversations: allConversations.length,
          totalMessages: allMessages.length,
          conversations: allConversations,
          messages: allMessages,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── ACTION: CLEAR_CHAT ────────────────────────────────────
    // Delete all messages for a specific chat (clear chat).
    if (action === "clearChat") {
      if (!chatId) {
        return new Response(
          JSON.stringify({ error: "chatId is required for clearChat" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      let deleted = 0;
      let skip = 0;
      let hasMore = true;
      while (hasMore) {
        const msgs = await db.entities.ChatMessage.filter(
          { userEmail: userEmail, chatId: chatId },
          undefined,
          500,
          skip
        );
        if (msgs && msgs.length > 0) {
          for (const msg of msgs) {
            await db.entities.ChatMessage.delete(msg.id);
            deleted++;
          }
          skip += msgs.length;
        }
        hasMore = msgs && msgs.length === 500;
      }

      return new Response(
        JSON.stringify({ success: true, deletedMessages: deleted }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: `Chat sync failed: ${err.message || "Unknown error"}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
