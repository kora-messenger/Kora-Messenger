const mongoose = require('mongoose');

// Mirrors the app's ChatMessage entity — scoped by userEmail.
const chatMessageSchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    chatId: { type: String, required: true },
    messageId: { type: String, required: true },
    text: { type: String, default: '' },
    // ISO string from the app — stored as-is for exact round-tripping.
    timestamp: { type: String, default: '' },
    isMe: { type: Boolean, default: false },
    type: { type: String, default: 'text' },
    status: { type: String, default: 'none' },
    replyToId: { type: String, default: '' },
    replyToText: { type: String, default: '' },
    replyToName: { type: String, default: '' },
    reaction: { type: String, default: '' },
    voiceDuration: { type: String, default: '' },
    voiceFilePath: { type: String, default: '' },
    voiceFileUrl: { type: String, default: '' },
    voiceTranscript: { type: String, default: '' },
    mediaUrl: { type: String, default: '' },
    mediaCaption: { type: String, default: '' },
    isViewOnce: { type: Boolean, default: false },
    mediaWidth: { type: Number, default: 0 },
    mediaHeight: { type: Number, default: 0 },
    mediaDuration: { type: String, default: '' },
    isAi: { type: Boolean, default: false },
    isWebSearch: { type: Boolean, default: false },
    isSeen: { type: Boolean, default: false },
    isStarred: { type: Boolean, default: false },
    actionLabel: { type: String, default: '' },
    actionType: { type: String, default: '' },
  },
  { timestamps: true }
);

chatMessageSchema.index(
  { userEmail: 1, messageId: 1 },
  { unique: true }
);
chatMessageSchema.index({ userEmail: 1, timestamp: 1 });
chatMessageSchema.index({ userEmail: 1, chatId: 1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
