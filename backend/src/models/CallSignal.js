const mongoose = require('mongoose');

const callSignalSchema = new mongoose.Schema(
  {
    callId: { type: String, required: true, index: true },
    callerEmail: { type: String, default: '', lowercase: true, trim: true },
    calleeEmail: { type: String, default: '', lowercase: true, trim: true },
    callType: { type: String, default: 'voice' },
    offerSdp: { type: String, default: null },
    answerSdp: { type: String, default: null },
    callerCandidates: { type: String, default: '[]' },
    calleeCandidates: { type: String, default: '[]' },
    status: { type: String, default: 'ringing' },
    createdAt: { type: String, default: () => new Date().toISOString() },
  },
  { timestamps: false }
);

callSignalSchema.index({ calleeEmail: 1, status: 1 });

module.exports = mongoose.model('CallSignal', callSignalSchema);
