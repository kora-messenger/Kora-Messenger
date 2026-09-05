const express = require('express');
const Conversation = require('../models/Conversation');
const ChatMessage = require('../models/ChatMessage');
const User = require('../models/User');

const router = express.Router();

// Kora Chat Sync — 1:1 mirror of the Base44 koraChatSync function.
//
// Actions:
// 1. "sync"      — Save new/updated messages + conversations, and
//                  deliver messages to the recipient's account.
// 2. "fetch"     — Load all conversations + messages (login/reinstall).
// 3. "fetchNew"  — Load data updated after sinceTimestamp (polling).
// 4. "backup"    — Export all chat data (Chat Backup screen).
// 5. "clearChat" — Delete all messages for a specific chat.
//
// Everything is scoped by userEmail (row-level security), so logging
// in with the same email restores all chats on a fresh install.

// Badge derivation — see KoraBadgeType in lib/models/chat_models.dart.
// Owner accounts get the purple "official" badge — must stay in sync
// with kOwnerEmails in lib/theme/chat_theme_provider.dart.
// 0 = none, 1 = officialPurple (owner), 2 = premiumBlue (premium),
// -1 = user not found (caller keeps its own value).
const OWNER_EMAILS = new Set([
  'goodluckijezie9@gmail.com',
  'ijeziegoodluck7@gmail.com',
  'ijeziegoodluck4@gmail.com',
  'ijeziegoodluck96@gmail.com',
]);

async function deriveBadgeFor(email) {
  try {
    const normalized = String(email ?? '').toLowerCase().trim();
    if (!normalized) return 0;
    if (OWNER_EMAILS.has(normalized)) return 1;
    const user = await User.findOne({ email: normalized });
    if (!user) return -1; // user not found
    return User.computeIsPremium(user) ? 2 : 0;
  } catch (_) {
    return 0;
  }
}

// Map entity docs to the standard response schema the app parses.
function mapConversation(c) {
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

function mapMessage(m) {
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

// True when value is a valid date strictly after sinceTimestamp.
// Falls back to raw string comparison when either side isn't a
// valid date (mirrors the Base44 in-memory re-filter).
function isAfter(value, sinceTimestamp) {
  if (!value) return false;
  const sinceTime = new Date(sinceTimestamp).getTime();
  const valueTime = new Date(value).getTime();
  if (!Number.isNaN(sinceTime) && !Number.isNaN(valueTime)) {
    return valueTime > sinceTime;
  }
  return String(value) > String(sinceTimestamp);
}

// Raw record shape (backup) — flat fields + id/created/updated dates.
function rawDoc(doc) {
  const out = doc.toObject();
  out.id = String(out._id);
  out.created_date = doc.createdAt ? doc.createdAt.toISOString() : null;
  out.updated_date = doc.updatedAt ? doc.updatedAt.toISOString() : null;
  delete out._id;
  delete out.__v;
  return out;
}

function err(res, message, status = 400) {
  return res.status(status).json({ error: message });
}

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action, userEmail } = body;
  const {
    recipientEmail, recipientName, senderName,
    messages, conversations, chatId, sinceTimestamp,
  } = body;

  if (!userEmail) return err(res, 'userEmail is required');
  const owner = String(userEmail).toLowerCase().trim();

  try {
    // ── ACTION: SYNC ────────────────────────────────────────
    // Save messages and conversations; copy messages to the
    // recipient's account so they appear on their next poll.
    if (action === 'sync') {
      let savedMessages = 0;
      let savedConversations = 0;

      if (Array.isArray(messages) && messages.length > 0) {
        for (const msg of messages) {
          const existing = await ChatMessage.findOne({
            userEmail: owner,
            messageId: msg.messageId,
          });

          if (existing) {
            // Update existing message (status, isSeen, etc.)
            existing.status = msg.status ?? existing.status;
            existing.isSeen = msg.isSeen ?? existing.isSeen;
            existing.isStarred = msg.isStarred ?? false;
            existing.reaction = msg.reaction ?? existing.reaction;
            // Media fields may arrive later (upload finishes after send)
            if (msg.mediaUrl !== undefined && msg.mediaUrl !== null) {
              existing.mediaUrl = msg.mediaUrl;
            }
            if (msg.voiceFileUrl !== undefined && msg.voiceFileUrl !== null) {
              existing.voiceFileUrl = msg.voiceFileUrl;
            }
            await existing.save();
          } else {
            await ChatMessage.create({
              userEmail: owner,
              chatId: msg.chatId,
              messageId: msg.messageId,
              text: msg.text || '',
              timestamp: msg.timestamp,
              isMe: msg.isMe ?? false,
              type: msg.type || 'text',
              status: msg.status || 'none',
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

      // ── Cross-user delivery: copy to recipient's account ──
      let deliveredNew = false;
      if (recipientEmail && Array.isArray(messages) && messages.length > 0) {
        const recipient = String(recipientEmail).toLowerCase().trim();
        for (const msg of messages) {
          // Different messageId for the recipient's copy
          const recipientMsgId = 'recv_' + msg.messageId;

          const recvExisting = await ChatMessage.findOne({
            userEmail: recipient,
            messageId: recipientMsgId,
          });

          if (!recvExisting) {
            await ChatMessage.create({
              userEmail: recipient,
              chatId: msg.chatId,
              messageId: recipientMsgId,
              text: msg.text || '',
              timestamp: msg.timestamp,
              isMe: false, // recipient sees it as incoming
              type: msg.type || 'text',
              status: 'none',
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

        // Create/update the recipient's conversation — only when a NEW
        // message was delivered (don't bump unreadCount on re-syncs).
        if (recipientName && deliveredNew) {
          const lastMsg = messages[messages.length - 1];
          const recvConv = await Conversation.findOne({
            userEmail: recipient,
            chatId: lastMsg.chatId,
          });

          if (recvConv) {
            // Keep the badge fresh — the sender may have become premium
            // (or an owner) after this conversation was created.
            const senderBadge = Math.max(0, await deriveBadgeFor(owner));
            recvConv.recipientEmail = owner; // sender's email, so replies route back
            if (senderName) recvConv.name = senderName;
            recvConv.badge = senderBadge;
            recvConv.lastMessageText = lastMsg.text || '';
            recvConv.lastMessageTimestamp = lastMsg.timestamp;
            recvConv.lastMessageType = lastMsg.type || 'text';
            recvConv.unreadCount = (recvConv.unreadCount || 0) + 1;
            await recvConv.save();
          } else {
            await Conversation.create({
              userEmail: recipient,
              recipientEmail: owner, // sender's email, so replies route back
              chatId: lastMsg.chatId,
              name: senderName || 'Unknown',
              badge: await deriveBadgeFor(owner),
              isOnline: true,
              lastMessageText: lastMsg.text || '',
              lastMessageTimestamp: lastMsg.timestamp,
              lastMessageType: lastMsg.type || 'text',
              unreadCount: 1,
            });
          }
        }
      }

      // Save/update conversations (batch)
      if (Array.isArray(conversations) && conversations.length > 0) {
        for (const conv of conversations) {
          const existing = await Conversation.findOne({
            userEmail: owner,
            chatId: conv.chatId,
          });

          // Derive the other user's badge from their profile so badges
          // propagate to every device. When the profile is found it's
          // authoritative (handles premium revocation too); otherwise
          // keep the client's value (group chats / channels).
          const derivedBadge = await deriveBadgeFor(
            conv.recipientEmail ?? (existing ? existing.recipientEmail : null)
          );
          const finalBadge = derivedBadge >= 0 ? derivedBadge : (conv.badge ?? 0);

          if (existing) {
            existing.name = conv.name;
            existing.avatarAsset = conv.avatarAsset;
            existing.avatarUrl = conv.avatarUrl;
            existing.badge = finalBadge;
            existing.isOnline = conv.isOnline ?? false;
            existing.lastMessageText = conv.lastMessageText;
            existing.lastMessageTimestamp = conv.lastMessageTimestamp;
            existing.lastMessageType = conv.lastMessageType;
            existing.lastVoiceDuration = conv.lastVoiceDuration;
            existing.unreadCount = conv.unreadCount ?? 0;
            await existing.save();
          } else {
            await Conversation.create({
              userEmail: owner,
              chatId: conv.chatId,
              recipientEmail: conv.recipientEmail ?? '',
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

      return res.json({ success: true, savedMessages, savedConversations });
    }

    // ── ACTION: FETCH ───────────────────────────────────────
    // Load all conversations + messages for a user.
    if (action === 'fetch') {
      const allConversations = await Conversation.find({ userEmail: owner })
        .sort({ lastMessageTimestamp: -1 });
      const allMessages = await ChatMessage.find({ userEmail: owner })
        .sort({ timestamp: 1 });

      return res.json({
        success: true,
        conversations: allConversations.map(mapConversation),
        messages: allMessages.map(mapMessage),
      });
    }

    // ── ACTION: FETCH_NEW ──────────────────────────────────
    // Conversations + messages updated after sinceTimestamp.
    if (action === 'fetchNew') {
      const convQuery = { userEmail: owner };
      if (sinceTimestamp) {
        convQuery.updatedAt = { $gt: new Date(sinceTimestamp) };
      }
      const allConversations = await Conversation.find(convQuery)
        .sort({ lastMessageTimestamp: -1 });

      // In-memory re-filter, mirroring the Base44 behavior: compare
      // updatedAt, falling back to lastMessageTimestamp.
      const filteredConversations = sinceTimestamp
        ? allConversations.filter((c) => {
            const raw = c.updatedAt || c.lastMessageTimestamp;
            return !raw ? true : isAfter(raw, sinceTimestamp);
          })
        : allConversations;

      const msgQuery = { userEmail: owner };
      if (sinceTimestamp) {
        msgQuery.timestamp = { $gt: sinceTimestamp };
      }
      const allMessages = await ChatMessage.find(msgQuery)
        .sort({ timestamp: 1 });

      const filteredMessages = sinceTimestamp
        ? allMessages.filter((m) => isAfter(m.timestamp, sinceTimestamp))
        : allMessages;

      return res.json({
        success: true,
        conversations: filteredConversations.map(mapConversation),
        messages: filteredMessages.map(mapMessage),
      });
    }

    // ── ACTION: BACKUP ──────────────────────────────────────
    // Export all chat data — used by the Chat Backup screen.
    if (action === 'backup') {
      const allConversations = await Conversation.find({ userEmail: owner });
      const allMessages = await ChatMessage.find({ userEmail: owner });

      return res.json({
        success: true,
        backupDate: new Date().toISOString(),
        totalConversations: allConversations.length,
        totalMessages: allMessages.length,
        conversations: allConversations.map(rawDoc),
        messages: allMessages.map(rawDoc),
      });
    }

    // ── ACTION: CLEAR_CHAT ──────────────────────────────────
    // Delete all messages for a specific chat.
    if (action === 'clearChat') {
      if (!chatId) return err(res, 'chatId is required for clearChat');
      const result = await ChatMessage.deleteMany({
        userEmail: owner,
        chatId,
      });
      return res.json({ success: true, deletedMessages: result.deletedCount || 0 });
    }

    return err(res, `Unknown action: ${action}`);
  } catch (e) {
    console.error(`[koraChatSync] action=${action} error:`, e);
    return err(res, `Chat sync failed: ${e.message || 'Unknown error'}`, 500);
  }
});

module.exports = router;
