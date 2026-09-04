const mongoose = require('mongoose');

// Mirrors the app's KoraUser entity + KoraUserSession.fromMap shape.
const deviceSchema = new mongoose.Schema(
  {
    deviceId: { type: String, required: true },
    deviceName: { type: String, default: 'Unknown device' },
    platform: { type: String, default: 'unknown' },
    firstLoginDate: { type: Date, default: Date.now },
    lastLoginDate: { type: Date, default: Date.now },
    isTrusted: { type: Boolean, default: true },
    isActive: { type: Boolean, default: true },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, default: '' },
    fullName: { type: String, default: '' },
    username: { type: String, sparse: true, trim: true },
    koraId: { type: String, required: true, unique: true },
    bio: { type: String, default: '' },
    avatarUrl: { type: String, default: '' },
    phoneNumber: { type: String, default: '' },
    profileCompleted: { type: Boolean, default: false },
    isPremium: { type: Boolean, default: false },
    premiumExpiresAt: { type: Date, default: null },
    premiumSource: { type: String, default: null },
    isVerified: { type: Boolean, default: false },
    isSuspended: { type: Boolean, default: false },
    passkeysEnabled: { type: Boolean, default: false },
    securePinHash: { type: String, default: '' },
    publicKey: { type: String, default: '' },
    signingKey: { type: String, default: '' },
    devices: [deviceSchema],
  },
  { timestamps: true }
);

userSchema.index({ username: 1 }, { unique: true, sparse: true, collation: { locale: 'en', strength: 2 } });

// Shape the app expects in KoraUserSession.fromMap / saveSession.
userSchema.methods.toClient = function toClient() {
  return {
    id: this._id.toString(),
    email: this.email,
    fullName: this.fullName,
    username: this.username || '',
    koraId: this.koraId,
    bio: this.bio || '',
    avatarUrl: this.avatarUrl || '',
    phoneNumber: this.phoneNumber || '',
    profileCompleted: this.profileCompleted,
    isPremium: this.isPremium,
    isVerified: this.isVerified,
    isSuspended: this.isSuspended,
    passkeysEnabled: this.passkeysEnabled,
    createdAt: this.createdAt ? this.createdAt.toISOString() : null,
  };
};

module.exports = mongoose.model('User', userSchema);
