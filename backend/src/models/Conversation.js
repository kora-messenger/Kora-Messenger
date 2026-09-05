const mongoose = require('mongoose');

// Mirrors the app's Conversation entity — one per user per chat,
// scoped by userEmail (row-level security, same as Base44).
const conversationSchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    chatId: { type: String, required: true },
    recipientEmail: { type: String, default: '' },
    name: { type: String, default: '' },
    avatarAsset: { type: String, default: '' },
    avatarUrl: { type: String, default: '' },
    badge: { type: Number, default: 0 },
    isOnline: { type: Boolean, default: false },
    lastMessageText: { type: String, default: '' },
    // Kept as a string so the exact app value round-trips unchanged.
    lastMessageTimestamp: { type: String, default: '' },
    lastMessageType: { type: String, default: 'text' },
    lastVoiceDuration: { type: String, default: '' },
    unreadCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

conversationSchema.index(
  { userEmail: 1, chatId: 1 },
  { unique: true }
);
conversationSchema.index({ userEmail: 1, lastMessageTimestamp: -1 });
// fetchNew polls on updatedAt.
conversationSchema.index({ userEmail: 1, updatedAt: -1 });

module.exports = mongoose.model('Conversation', conversationSchema);
