const express = require('express');
const crypto = require('crypto');
const User = require('../models/User');
const TrustedDevice = require('../models/TrustedDevice');
const VerificationCode = require('../models/VerificationCode');

const router = express.Router();

// Generate a random 32-byte URL-safe base64 token
function generateToken() {
  return crypto.randomBytes(32).toString('base64url');
}

router.post('/', async (req, res) => {
  try {
    const body = req.body || {};
    const { action } = body;

    // ── ACTION: requestPair ──────────────────────────────────────────────
    if (action === 'requestPair') {
      const token = generateToken();
      // Telegram-style: pairing codes are short-lived and rotate automatically.
      const ttlSeconds = 30;
      const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();

      await VerificationCode.create({
        email: '',
        code: token,
        type: 'web_pair',
        used: false,
        expiresAt: new Date(expiresAt),
        attempts: 0,
      });

      const qrData = `kora://link?token=${token}&web=true`;

      return res.json({
        success: true,
        pairingToken: token,
        qrData,
        expiresAt,
        ttlSeconds,
      });
    }

    // ── ACTION: pollPair ─────────────────────────────────────────────────
    if (action === 'pollPair') {
      const token = body.token || body.pairingToken;
      if (!token) {
        return res.status(400).json({ success: false, error: 'Token is required' });
      }

      const vCode = await VerificationCode.findOne({
        code: token,
        type: 'web_pair',
      });

      if (!vCode) {
        return res.json({ success: true, status: 'expired' });
      }

      const used = vCode.used ?? false;
      const email = vCode.email ?? '';
      const expiresAtDate = new Date(vCode.expiresAt);
      const isExpired = isNaN(expiresAtDate.getTime()) || expiresAtDate.getTime() < Date.now();

      if (used) {
        if (!email) {
          return res.json({ success: true, status: 'expired' });
        }

        const lowerEmail = String(email).toLowerCase().trim();
        const user = await User.findOne({ email: lowerEmail });

        if (!user) {
          return res.json({ success: true, status: 'expired' });
        }

        const userData = {
          id: user._id.toString(),
          email: user.email || lowerEmail,
          username: user.username || '',
          koraId: user.koraId || '',
          fullName: user.fullName || '',
          bio: user.bio || '',
          avatarUrl: user.avatarUrl || '',
          isVerified: user.isVerified ?? false,
          profileCompleted: user.profileCompleted ?? false,
          phoneNumber: user.phoneNumber || '',
          isPremium: User.computeIsPremium ? User.computeIsPremium(user) : (user.isPremium ?? false),
        };

        return res.json({
          success: true,
          status: 'accepted',
          user: userData,
        });
      }

      if (isExpired) {
        return res.json({ success: true, status: 'expired' });
      }

      return res.json({ success: true, status: 'pending' });
    }

    // ── ACTION: acceptPair ───────────────────────────────────────────────
    if (action === 'acceptPair') {
      const token = body.token || body.pairingToken;
      const email = body.email || body.userEmail || body.ownerEmail;
      const acceptorDeviceId = body.deviceId;

      if (!token || !email) {
        return res.status(400).json({ success: false, error: 'Token and email are required' });
      }
      if (!deviceId) {
        return res.status(400).json({ success: false, error: 'Device verification required. Update Kora to the latest version.' });
      }

      const vCode = await VerificationCode.findOne({
        code: token,
        type: 'web_pair',
      });

      if (!vCode) {
        return res.json({ success: false, error: 'Invalid pairing code' });
      }

      const used = vCode.used ?? false;
      const expiresAtDate = new Date(vCode.expiresAt);
      const isExpired = isNaN(expiresAtDate.getTime()) || expiresAtDate.getTime() < Date.now();

      if (used || isExpired) {
        return res.json({ success: false, error: 'Pairing code expired or already used' });
      }

      const lowerEmail = String(email).toLowerCase().trim();
      const user = await User.findOne({ email: lowerEmail });

      if (!user) {
        return res.json({ success: false, error: 'Account not found' });
      }

      // Only a device already signed in on this account may accept a pairing —
      // mirrors Telegram's rule that auth.acceptLoginToken is called by an
      // already-authorized session.
      const enrolled = (user.devices || []).some(
        (d) => d && d.deviceId === acceptorDeviceId && d.isActive !== false
      );
      if (!enrolled) {
        return res.json({ success: false, error: 'This device is not signed in on that account' });
      }

      // Mark VerificationCode as used and set email
      vCode.used = true;
      vCode.email = lowerEmail;
      await vCode.save();

      // Register web device in TrustedDevice
      const now = new Date().toISOString();
      const deviceId = 'web-' + token.substring(0, 8);

      const existingDevice = await TrustedDevice.findOne({
        userEmail: lowerEmail,
        deviceId,
      });

      if (existingDevice) {
        existingDevice.lastLoginDate = now;
        existingDevice.isActive = true;
        existingDevice.isTrusted = true;
        existingDevice.deviceName = 'Kora Web';
        existingDevice.platform = 'web';
        await existingDevice.save();
      } else {
        await TrustedDevice.create({
          userEmail: lowerEmail,
          deviceId,
          deviceName: 'Kora Web',
          platform: 'web',
          firstLoginDate: now,
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
        });
      }

      return res.json({
        success: true,
        message: 'Web device linked',
      });
    }

    // ── ACTION: extendToken ──────────────────────────────────────────────
    return res.status(400).json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
