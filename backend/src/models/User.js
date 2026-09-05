const mongoose = require('mongoose');

// Mirrors the app's KoraUser entity + KoraUserSession.fromMap shape.
// Passkeys are embedded (Base44 kept them in a separate entity; here the
// account owns them directly). keyId is the client-facing "passkey id".
const passkeySchema = new mongoose.Schema(
  {
    keyId: { type: String, required: true },
    deviceId: { type: String, required: true },
    deviceName: { type: String, default: 'Unknown Device' },
    platform: { type: String, default: 'unknown' },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

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
    username: { type: String, trim: true },
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
    suspensionReason: { type: String, default: '' },
    suspensionTimestamp: { type: String, default: '' },
    suspensionExpiresAt: { type: String, default: '' },
    suspensionAppealStatus: { type: String, default: 'none' },
    role: { type: String, default: 'user' },
    passkeysEnabled: { type: Boolean, default: false },
    securePinHash: { type: String, default: '' },
    publicKey: { type: String, default: '' },
    signingKey: { type: String, default: '' },
    fcmToken: { type: String, default: null },
    fcmPlatform: { type: String, default: null },
    fcmTokenUpdatedAt: { type: String, default: null },
    devices: [deviceSchema],
    passkeys: [passkeySchema],
  },
  { timestamps: true }
);

userSchema.index({ username: 1 }, { unique: true, sparse: true, collation: { locale: 'en', strength: 2 } });

// Premium is true if isPremium is set AND (no expiry, or expiry is in
// the future). Owner-override grants (premiumSource: 'owner_override')
// never expire regardless of premiumExpiresAt.
userSchema.statics.computeIsPremium = function computeIsPremium(user) {
  if (!user.isPremium) return false;
  if (user.premiumSource === 'owner_override') return true;
  if (!user.premiumExpiresAt) return true;
  return new Date(user.premiumExpiresAt).getTime() > Date.now();
};

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
    isPremium: this.constructor.computeIsPremium(this),
    premiumExpiresAt: this.premiumExpiresAt ? new Date(this.premiumExpiresAt).toISOString() : null,
    premiumSource: this.premiumSource || '',
    isVerified: this.isVerified,
    isSuspended: this.isSuspended,
    passkeysEnabled: this.passkeysEnabled,
    createdAt: this.createdAt ? this.createdAt.toISOString() : null,
  };
};

module.exports = mongoose.model('User', userSchema);
