import mongoose from 'mongoose';

const suspensionRecordSchema = new mongoose.Schema(
  {
    appealDecision: { type: String },
    appealMessage: { type: String },
    appealSubmittedAt: { type: Date },
    autoDetected: { type: Boolean },
    detectionDetails: { type: String },
    detectionType: { type: String },
    expiresAt: { type: Date },
    ownerNotified: { type: Boolean },
    resolved: { type: Boolean },
    reason: { type: String },
    status: { type: String },
    suspendedAt: { type: Date },
    suspendedBy: { type: String },
    userEmail: { type: String },
    userKoraId: { type: String },
    username: { type: String },
  },
  {
    timestamps: true,
  }
);

export const SuspensionRecord = mongoose.model('SuspensionRecord', suspensionRecordSchema);
export default SuspensionRecord;
