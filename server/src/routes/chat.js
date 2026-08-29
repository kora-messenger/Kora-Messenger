import { Router } from 'express';
import ChatMessage from '../models/ChatMessage.js';
import Conversation from '../models/Conversation.js';

const router = Router();

router.post('/', async (req, res) => {
  const { action } = req.body;

  try {
    // ── SYNC ──
    if (action === 'sync') {
      const { userEmail, messages = [], conversations = [] } = req.body;
      let msgCount = 0, convCount = 0;

      for (const msg of messages) {
        const existing = await ChatMessage.findOne({ messageId: msg.messageId, userEmail });
        if (existing) {
          Object.assign(existing, msg);
          await existing.save();
        } else {
          await ChatMessage.create({ ...msg, userEmail });
          msgCount++;
          // Increment unread on conversation if message is from someone else
          if (!msg.isMe && msg.chatId) {
            const conv = await Conversation.findOne({ chatId: msg.chatId, userEmail });
            if (conv) {
              conv.unreadCount = (conv.unreadCount || 0) + 1;
              conv.lastMessageText = msg.text || msg.lastMessageText || '';
              conv.lastMessageTimestamp = msg.timestamp || new Date();
              conv.lastMessageType = msg.type || 'text';
              await conv.save();
            }
          }
        }
      }

      for (const conv of conversations) {
        const filter = { chatId: conv.chatId, userEmail };
        const update = {
          $set: {
            name: conv.name,
            avatarUrl: conv.avatarUrl,
            avatarAsset: conv.avatarAsset,
            badge: conv.badge,
            isOnline: conv.isOnline,
            unreadCount: conv.unreadCount || 0,
            lastMessageText: conv.lastMessageText || '',
            lastMessageTimestamp: conv.lastMessageTimestamp || new Date(),
            lastMessageType: conv.lastMessageType || 'text',
            lastVoiceDuration: conv.lastVoiceDuration,
            recipientEmail: conv.recipientEmail,
          },
        };
        await Conversation.updateOne(filter, update, { upsert: true });
        convCount++;
      }

      return res.json({ success: true, synced: { messages: msgCount, conversations: convCount } });
    }

    // ── FETCH ──
    if (action === 'fetch') {
      const { userEmail, chatId, limit = 100, skip = 0 } = req.body;
      const messages = await ChatMessage.find({ userEmail, chatId })
        .sort({ timestamp: 1 })
        .skip(skip)
        .limit(limit);
      return res.json({ success: true, messages });
    }

    // ── FETCH NEW ──
    if (action === 'fetchNew') {
      const { userEmail, lastTimestamp } = req.body;
      const query = { userEmail };
      if (lastTimestamp) {
        query.timestamp = { $gt: new Date(lastTimestamp) };
      }
      const messages = await ChatMessage.find(query).sort({ timestamp: 1 });
      const latestTimestamp = messages.length > 0 ? messages[messages.length - 1].timestamp : null;
      return res.json({ success: true, messages, latestTimestamp });
    }

    // ── BACKUP / RESTORE ──
    if (action === 'backup') {
      const { userEmail, messages = [], conversations = [] } = req.body;
      await ChatMessage.deleteMany({ userEmail });
      await Conversation.deleteMany({ userEmail });
      if (messages.length > 0) {
        await ChatMessage.insertMany(messages.map(m => ({ ...m, userEmail })));
      }
      if (conversations.length > 0) {
        await Conversation.insertMany(conversations.map(c => ({ ...c, userEmail })));
      }
      return res.json({ success: true, restored: { messages: messages.length, conversations: conversations.length } });
    }

    // ── CLEAR CHAT ──
    if (action === 'clearChat') {
      const { userEmail, chatId } = req.body;
      await ChatMessage.deleteMany({ userEmail, chatId });
      await Conversation.updateOne(
        { chatId, userEmail },
        { $set: { lastMessageText: '', lastMessageTimestamp: null, lastMessageType: null } }
      );
      return res.json({ success: true });
    }

    return res.status(400).json({ error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('Chat route error:', err);
    return res.status(500).json({ error: 'Internal server error', detail: err.message });
  }
});

export default router;
