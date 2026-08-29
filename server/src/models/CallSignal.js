import mongoose from 'mongoose';

const callSignalSchema = new mongoose.Schema(
  {
    answerSdp: { type: String },
    callId: { type: String },
    callType: { type: String },
    calleeCandidates: { type: Array },
    calleeEmail: { type: String },
    callerCandidates: { type: Array },
    callerEmail: { type: String },
    createdAt: { type: Date, default: Date.now },
    offerSdp: { type: String },
    status: { type: String },
  },
  {
    timestamps: true,
  }
);

export const CallSignal = mongoose.model('CallSignal', callSignalSchema);
export default CallSignal;
