import mongoose from 'mongoose';

const chatMessageSchema = new mongoose.Schema(
  {
    actionLabel: { type: String },
    actionType: { type: String },
    chatId: { type: String },
    isAi: { type: Boolean, default: false },
    isMe: { type: Boolean },
    isSeen: { type: Boolean, default: false },
    isStarred: { type: Boolean, default: false },
    isWebSearch: { type: Boolean, default: false },
    lastMessageText: { type: String },
    lastMessageTimestamp: { type: Date },
    lastMessageType: { type: String },
    lastVoiceDuration: { type: Number },
    messageId: { type: String },
    reaction: { type: String },
    replyToId: { type: String },
    replyToName: { type: String },
    replyToText: { type: String },
    status: { type: String },
    text: { type: String },
    timestamp: { type: Date },
    translatedLanguageCode: { type: String },
    translatedLanguageName: { type: String },
    type: { type: String },
    userEmail: { type: String },
    voiceDuration: { type: Number },
    voiceFilePath: { type: String },
    voiceTranscript: { type: String },
  },
  {
    timestamps: true,
  }
);

export const ChatMessage = mongoose.model('ChatMessage', chatMessageSchema);
export default ChatMessage;
