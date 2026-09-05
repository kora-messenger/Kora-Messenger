const express = require('express');
const User = require('../models/User');
const VerificationCode = require('../models/VerificationCode');
const { sendVerificationCode, sendSecurityAlertEmail } = require('../mailer');

const router = express.Router();

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function getUserFromRecord(record) {
  return {
    id: record._id ? record._id.toString() : (record.id || ''),
    email: record.email || '',
    username: record.username || '',
    koraId: record.koraId || '',
    fullName: record.fullName || '',
    bio: record.bio || '',
    avatarUrl: record.avatarUrl || '',
    isVerified: record.isVerified ?? true,
    profileCompleted: record.profileCompleted ?? false,
    phoneNumber: record.phoneNumber || '',
  };
}

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action } = body;

  try {
    // ── INITIATE EMAIL CHANGE (sends code to OLD email) ───────
    if (action === 'initiateEmailChange') {
      const { userId, oldEmail, newEmail } = body;
      if (!userId || !oldEmail || !newEmail) {
        return res.json({ success: false, error: 'User ID, old email, and new email are required' });
      }

      const cleanOld = String(oldEmail).toLowerCase().trim();
      const cleanNew = String(newEmail).toLowerCase().trim();

      const existing = await User.findOne({ email: cleanNew });
      if (existing && existing._id.toString() !== String(userId)) {
        return res.json({ success: false, error: 'An account with this email already exists' });
      }

      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

      await VerificationCode.updateMany(
        { email: cleanOld, type: 'emailChangeOld', used: false },
        { $set: { used: true } }
      );

      await VerificationCode.create({
        email: cleanOld,
        code,
        type: 'emailChangeOld',
        expiresAt,
        used: false,
        attempts: 0,
      });

      await sendVerificationCode(cleanOld, code, 'email_change');
      return res.json({ success: true, message: 'Verification code sent to your current email' });
    }

    // ── RESEND CODE (for old or new email) ────────────────────
    if (action === 'resendEmailChangeCode') {
      const { email, type } = body;
      if (!email || !type) {
        return res.json({ success: false, error: 'Email and type are required' });
      }

      const cleanEmail = String(email).toLowerCase().trim();
      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

      await VerificationCode.updateMany(
        { email: cleanEmail, type, used: false },
        { $set: { used: true } }
      );

      await VerificationCode.create({
        email: cleanEmail,
        code,
        type,
        expiresAt,
        used: false,
        attempts: 0,
      });

      await sendVerificationCode(cleanEmail, code, 'email_change');
      return res.json({ success: true, message: 'Code resent' });
    }

    // ── VERIFY OLD EMAIL (then sends code to NEW email) ─────
    if (action === 'verifyOldEmailForChange') {
      const { oldEmail, newEmail, code } = body;
      if (!oldEmail || !newEmail || !code) {
        return res.json({ success: false, error: 'Old email, new email, and code are required' });
      }

      const cleanOld = String(oldEmail).toLowerCase().trim();
      const cleanNew = String(newEmail).toLowerCase().trim();

      const codes = await VerificationCode.find({ email: cleanOld, type: 'emailChangeOld', used: false }).sort({ createdAt: -1 });
      if (!codes || codes.length === 0) {
        return res.json({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c) => c.code === String(code));
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = (recent.attempts || 0) + 1;
        recent.attempts = attempts;
        if (attempts >= 5) {
          recent.used = true;
          await recent.save();
          return res.json({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        await recent.save();
        return res.json({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        matchingCode.used = true;
        await matchingCode.save();
        return res.json({ success: false, error: 'Code has expired. Request a new code.' });
      }

      matchingCode.used = true;
      await matchingCode.save();

      // Send code to NEW email
      const newCode = generateCode();
      const newExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

      await VerificationCode.updateMany(
        { email: cleanNew, type: 'changeEmail', used: false },
        { $set: { used: true } }
      );

      await VerificationCode.create({
        email: cleanNew,
        code: newCode,
        type: 'changeEmail',
        expiresAt: newExpiresAt,
        used: false,
        attempts: 0,
      });

      await sendVerificationCode(cleanNew, newCode, 'email_change');
      return res.json({ success: true, message: 'Verification code sent to your new email' });
    }

    // ── VERIFY NEW EMAIL AND UPDATE ──────────────────────────
    if (action === 'verifyAndUpdateEmail') {
      const { userId, newEmail, oldEmail, code } = body;
      if (!userId || !newEmail || !code) {
        return res.json({ success: false, error: 'User ID, new email, and code are required' });
      }

      const cleanNew = String(newEmail).toLowerCase().trim();
      const cleanOld = oldEmail ? String(oldEmail).toLowerCase().trim() : '';

      const codes = await VerificationCode.find({ email: cleanNew, type: 'changeEmail', used: false }).sort({ createdAt: -1 });
      if (!codes || codes.length === 0) {
        return res.json({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c) => c.code === String(code));
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = (recent.attempts || 0) + 1;
        recent.attempts = attempts;
        if (attempts >= 5) {
          recent.used = true;
          await recent.save();
          return res.json({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        await recent.save();
        return res.json({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        matchingCode.used = true;
        await matchingCode.save();
        return res.json({ success: false, error: 'Code has expired. Request a new code.' });
      }

      const existing = await User.findOne({ email: cleanNew });
      if (existing && existing._id.toString() !== String(userId)) {
        return res.json({ success: false, error: 'An account with this email already exists' });
      }

      matchingCode.used = true;
      await matchingCode.save();

      const user = await User.findById(userId);
      if (!user) {
        return res.json({ success: false, error: 'User not found' });
      }

      user.email = cleanNew;
      await user.save();

      // Send security alert to old email
      if (cleanOld) {
        try {
          const timestamp = new Date().toLocaleString('en-US', { timeZone: 'UTC', dateStyle: 'full', timeStyle: 'short' });
          await sendSecurityAlertEmail(cleanOld, 'Kora Account', `Email address changed to ${cleanNew}`, timestamp);
        } catch (e) {
          console.error('Failed to send email change alert:', e);
        }
      }

      return res.json({ success: true, user: getUserFromRecord(user) });
    }

    return res.json({ success: false, error: `Unknown action: ${action}` });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
