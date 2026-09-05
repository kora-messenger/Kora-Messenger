const mongoose = require('mongoose');

// Mirrors the app's SuspensionRecord entity.
const suspensionRecordSchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    userKoraId: { type: String, default: '' },
    username: { type: String, default: '' },
    detectionType: { type: String, default: 'other' },
    detectionDetails: { type: String, default: '' },
    reason: { type: String, default: '' },
    suspendedAt: { type: String, default: '' },
    // String type allows both ISO timestamps and 'permanent'
    expiresAt: { type: String, default: '' },
    status: { type: String, default: 'active' }, // 'active' | 'appealed' | 'resolved' | 'expired'
    autoDetected: { type: Boolean, default: true },
    suspendedBy: { type: String, default: 'automated_detection_system' },
    ownerNotified: { type: Boolean, default: false },
    resolved: { type: Boolean, default: false },
    appealDecision: { type: String, default: 'none' }, // 'none' | 'approved' | 'denied'
    appealMessage: { type: String, default: '' },
    appealSubmittedAt: { type: String, default: '' },
  },
  { timestamps: true }
);

suspensionRecordSchema.index({ userEmail: 1, status: 1 });
suspensionRecordSchema.index({ resolved: 1 });

module.exports = mongoose.model('SuspensionRecord', suspensionRecordSchema);
