import mongoose from 'mongoose';

const passkeySchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true },
    deviceId: { type: String },
    deviceName: { type: String },
    platform: { type: String },
    publicKey: { type: String },
    signingKey: { type: String },
  },
  {
    timestamps: true,
  }
);

export const Passkey = mongoose.model('Passkey', passkeySchema);
export default Passkey;
