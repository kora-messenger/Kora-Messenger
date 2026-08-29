import mongoose from 'mongoose';

const conversationSchema = new mongoose.Schema(
  {
    avatarAsset: { type: String },
    avatarUrl: { type: String },
    badge: { type: String },
    chatId: { type: String },
    isOnline: { type: Boolean },
    lastMessageText: { type: String },
    lastMessageTimestamp: { type: Date },
    lastMessageType: { type: String },
    lastVoiceDuration: { type: Number },
    name: { type: String },
    recipientEmail: { type: String },
    unreadCount: { type: Number, default: 0 },
    userEmail: { type: String },
  },
  {
    timestamps: true,
  }
);

export const Conversation = mongoose.model('Conversation', conversationSchema);
export default Conversation;
