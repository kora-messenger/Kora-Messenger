const mongoose = require('mongoose');

const trustedDeviceSchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    deviceId: { type: String, required: true },
    deviceName: { type: String, default: 'Unknown Device' },
    platform: { type: String, default: 'unknown' },
    firstLoginDate: { type: String, default: () => new Date().toISOString() },
    lastLoginDate: { type: String, default: () => new Date().toISOString() },
    isActive: { type: Boolean, default: true },
    isTrusted: { type: Boolean, default: true },
  },
  { timestamps: false }
);

trustedDeviceSchema.index({ userEmail: 1, deviceId: 1 });

module.exports = mongoose.model('TrustedDevice', trustedDeviceSchema);
