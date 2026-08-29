import mongoose from 'mongoose';

const verificationCodeSchema = new mongoose.Schema(
  {
    attempts: { type: Number, default: 0 },
    code: { type: String, required: true },
    email: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    type: { type: String },
    used: { type: Boolean, default: false },
  },
  {
    timestamps: true,
  }
);

export const VerificationCode = mongoose.model('VerificationCode', verificationCodeSchema);
export default VerificationCode;
