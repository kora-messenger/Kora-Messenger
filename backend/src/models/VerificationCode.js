const mongoose = require('mongoose');

const verificationCodeSchema = new mongoose.Schema(
  {
    email: { type: String, default: '', lowercase: true, trim: true },
    code: { type: String, required: true },
    type: { type: String, default: 'registration' },
    attempts: { type: Number, default: 0 },
    used: { type: Boolean, default: false },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true }
);

verificationCodeSchema.index({ email: 1, type: 1 });
verificationCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('VerificationCode', verificationCodeSchema);
