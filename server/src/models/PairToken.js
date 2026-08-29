import mongoose from 'mongoose';

const pairTokenSchema = new mongoose.Schema(
  {
    pairingToken: { type: String, required: true, unique: true },
    qrData: { type: String, required: true },
    userEmail: { type: String },
    deviceId: { type: String },
    status: { type: String, default: 'pending' },
    createdAt: { type: Date, default: Date.now, expires: 30 },
  },
  {
    timestamps: true,
  }
);

// Explicit TTL index on createdAt for 30 seconds expiration
pairTokenSchema.index({ createdAt: 1 }, { expireAfterSeconds: 30 });

export const PairToken = mongoose.model('PairToken', pairTokenSchema);
export default PairToken;
