import mongoose from 'mongoose';

const trustedDeviceSchema = new mongoose.Schema(
  {
    deviceName: { type: String },
    deviceId: { type: String },
    firstLoginDate: { type: Date },
    isActive: { type: Boolean, default: true },
    isTrusted: { type: Boolean, default: false },
    lastLoginDate: { type: Date },
    platform: { type: String },
    userEmail: { type: String },
  },
  {
    timestamps: true,
  }
);

export const TrustedDevice = mongoose.model('TrustedDevice', trustedDeviceSchema);
export default TrustedDevice;
