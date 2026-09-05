const mongoose = require('mongoose');

// Mirrors the app's UserSettings entity — one merged JSON settings
// blob per user (theme, notifications, privacy, wallpapers, ...).
const userSettingsSchema = new mongoose.Schema(
  {
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    settingsJson: { type: String, default: '{}' },
    keyCount: { type: Number, default: 0 },
    // ISO string, mirrors the Base44 updatedAt field (not the Mongo
    // timestamp — the app reads this value directly).
    updatedAt: { type: String, default: '' },
    deviceName: { type: String, default: 'unknown' },
  },
  // NOTE: no mongoose `timestamps` option — it would hijack the
  // updatedAt path and cast it to a Date, but the app expects the
  // ISO string we store (Base44 parity).
  { timestamps: false }
);

userSettingsSchema.index({ userEmail: 1 }, { unique: true });

module.exports = mongoose.model('UserSettings', userSettingsSchema);
