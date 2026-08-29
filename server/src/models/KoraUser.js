import mongoose from 'mongoose';

const koraUserSchema = new mongoose.Schema(
  {
    avatarUrl: { type: String },
    bio: { type: String },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    fullName: { type: String },
    isSuspended: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: false },
    koraId: { type: String, unique: true, sparse: true },
    passwordHash: { type: String },
    phoneNumber: { type: String },
    profileCompleted: { type: Boolean, default: false },
    securePinHash: { type: String },
    suspensionAppealStatus: { type: String },
    suspensionExpiresAt: { type: Date },
    suspensionReason: { type: String },
    suspensionTimestamp: { type: Date },
    username: {
      type: String,
      unique: true,
      lowercase: true,
      sparse: true,
      trim: true,
    },
    passkeysEnabled: { type: Boolean, default: false },
    isPremium: { type: Boolean, default: false },
    premiumExpiresAt: { type: Date },
    premiumSource: { type: String },
    publicKey: { type: String },
    signingKey: { type: String },
  },
  {
    timestamps: true,
  }
);

export const KoraUser = mongoose.model('KoraUser', koraUserSchema);
export default KoraUser;
