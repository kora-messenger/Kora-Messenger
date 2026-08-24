/**
 * Kora Chat Sync — Backend persistence for all chats and messages.
 *
 * This function handles three actions:
 * 1. "sync" — Save new/updated messages + conversations to the database
 * 2. "fetch" — Load all conversations + messages for a user (on login/reinstall)
 * 3. "backup" — Export all chat data for the user (for Chat Backup screen)
 *
 * Messages and conversations are scoped by userEmail (row-level security).
 * Even if the user deletes and reinstalls the app, logging in with the same
 * email restores all chats.
 *
 * Entity: Conversation, ChatMessage
 */

import { createClientFromRequest } from "npm:@base44/sdk@0.8.31";

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { action, userEmail, recipientEmail, recipientName, senderName, messages, conversations, chatId } = body;

    if (!userEmail) {
      return new Response(
        JSON.stringify({ error: "userEmail is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const base44 = createClientFromRequest(req);

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
          const existing = await base44.entities.ChatMessage.list({
            filter: {
              userEmail: userEmail,
              messageId: msg.messageId,
            },
            limit: 1,
          });

          if (existing && existing.length > 0) {
            // Update existing message (status, isSeen, etc.)
            await base44.entities.ChatMessage.update(existing[0]._id, {
              status: msg.status,
              isSeen: msg.isSeen,
              isStarred: msg.isStarred ?? false,
              reaction: msg.reaction,
            });
          } else {
            // Create new message
            await base44.entities.ChatMessage.create({
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
              voiceTranscript: msg.voiceTranscript,
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
      if (recipientEmail && messages && Array.isArray(messages) && messages.length > 0) {
        for (const msg of messages) {
          // Use a different messageId for the recipient's copy
          const recipientMsgId = 'recv_' + msg.messageId;
          const recipientChatId = msg.chatId;

          // Check if recipient already has this message
          const recvExisting = await base44.entities.ChatMessage.list({
            filter: {
              userEmail: recipientEmail,
              messageId: recipientMsgId,
            },
            limit: 1,
          });

          if (!recvExisting || recvExisting.length === 0) {
            await base44.entities.ChatMessage.create({
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
              voiceTranscript: msg.voiceTranscript,
              isAi: msg.isAi ?? false,
              isWebSearch: msg.isWebSearch ?? false,
              isSeen: false,
              isStarred: false,
              actionLabel: msg.actionLabel,
              actionType: msg.actionType,
            });
          }
        }

        // Also create/update a conversation for the recipient
        if (recipientName) {
          const lastMsg = messages[messages.length - 1];
          const recvConvExisting = await base44.entities.Conversation.list({
            filter: {
              userEmail: recipientEmail,
              chatId: lastMsg.chatId,
            },
            limit: 1,
          });

          if (recvConvExisting && recvConvExisting.length > 0) {
            await base44.entities.Conversation.update(recvConvExisting[0]._id, {
              name: senderName || recvConvExisting[0].name,
              lastMessageText: lastMsg.text || "",
              lastMessageTimestamp: lastMsg.timestamp,
              lastMessageType: lastMsg.type || "text",
              unreadCount: (recvConvExisting[0].unreadCount || 0) + 1,
            });
          } else {
            await base44.entities.Conversation.create({
              userEmail: recipientEmail,
              chatId: lastMsg.chatId,
              name: senderName || "Unknown",
              badge: 0,
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
          const existing = await base44.entities.Conversation.list({
            filter: {
              userEmail: userEmail,
              chatId: conv.chatId,
            },
            limit: 1,
          });

          if (existing && existing.length > 0) {
            // Update conversation metadata
            await base44.entities.Conversation.update(existing[0]._id, {
              name: conv.name,
              avatarAsset: conv.avatarAsset,
              avatarUrl: conv.avatarUrl,
              badge: conv.badge ?? 0,
              isOnline: conv.isOnline ?? false,
              lastMessageText: conv.lastMessageText,
              lastMessageTimestamp: conv.lastMessageTimestamp,
              lastMessageType: conv.lastMessageType,
              lastVoiceDuration: conv.lastVoiceDuration,
              unreadCount: conv.unreadCount ?? 0,
            });
          } else {
            // Create new conversation
            await base44.entities.Conversation.create({
              userEmail: userEmail,
              chatId: conv.chatId,
              name: conv.name || conv.chatId,
              avatarAsset: conv.avatarAsset,
              avatarUrl: conv.avatarUrl,
              badge: conv.badge ?? 0,
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
        const batch = await base44.entities.Conversation.list({
          filter: { userEmail: userEmail },
          limit: 500,
          skip: skipConv,
          sort: "-lastMessageTimestamp",
        });
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
        const batch = await base44.entities.ChatMessage.list({
          filter: { userEmail: userEmail },
          limit: 500,
          skip: skipMsg,
          sort: "timestamp",
        });
        if (batch && batch.length > 0) {
          allMessages.push(...batch);
          skipMsg += batch.length;
        }
        hasMoreMsg = batch && batch.length === 500;
      }

      return new Response(
        JSON.stringify({
          success: true,
          conversations: allConversations.map(c => ({
            chatId: c.chatId,
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
          })),
          messages: allMessages.map(m => ({
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
            voiceTranscript: m.voiceTranscript,
            isAi: m.isAi,
            isWebSearch: m.isWebSearch,
            isSeen: m.isSeen,
            isStarred: m.isStarred,
            actionLabel: m.actionLabel,
            actionType: m.actionType,
          })),
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
        const batch = await base44.entities.Conversation.list({
          filter: { userEmail: userEmail },
          limit: 500,
          skip: skipConv,
        });
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
        const batch = await base44.entities.ChatMessage.list({
          filter: { userEmail: userEmail },
          limit: 500,
          skip: skipMsg,
        });
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

      const messages = await base44.entities.ChatMessage.list({
        filter: { userEmail: userEmail, chatId: chatId },
        limit: 500,
      });

      let deleted = 0;
      if (messages && messages.length > 0) {
        for (const msg of messages) {
          await base44.entities.ChatMessage.delete(msg._id);
          deleted++;
        }
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
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Chat sync failed: ${err.message || "Unknown error"}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
