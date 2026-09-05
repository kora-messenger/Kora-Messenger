const express = require('express');
const crypto = require('crypto');
const User = require('../models/User');
const TrustedDevice = require('../models/TrustedDevice');

const router = express.Router();

const TOKEN_TTL_MS = 30 * 1000;

function generateToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function getClientIp(req) {
  const headers = req.headers || {};
  return (
    headers['cf-connecting-ip'] ||
    (headers['x-forwarded-for'] ? headers['x-forwarded-for'].split(',')[0].trim() : null) ||
    headers['x-real-ip'] ||
    req.ip ||
    'unknown'
  );
}

function getGeo(req) {
  const headers = req.headers || {};
  return {
    country: headers['cf-ipcountry'] || headers['x-vercel-ip-country'] || 'Unknown',
    region: headers['cf-region'] || headers['x-vercel-ip-country-region'] || '',
  };
}

router.post('/', async (req, res) => {
  try {
    const body = req.body || {};
    const { action } = body;

    // ── GENERATE PAIRING TOKEN (30s auto-refresh) ─────
    if (action === 'generatePairingToken') {
      const { email, appVersion } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();
      const user = await User.findOne({ email: lowerEmail });
      if (!user) {
        return res.json({ success: false, error: 'Account not found' });
      }

      const token = generateToken();
      const expiresAt = new Date(Date.now() + TOKEN_TTL_MS).toISOString();

      user.securePinHash = token;
      await user.save();

      const qrData = 'kora://link?token=' + token + '&email=' + encodeURIComponent(lowerEmail);

      return res.json({
        success: true,
        pairingToken: token,
        expiresAt,
        ttlSeconds: Math.floor(TOKEN_TTL_MS / 1000),
        qrData,
      });
    }

    // ── POLL PAIRING STATUS (Confirmation step) ──────
    if (action === 'pollPairingStatus') {
      const { pairingToken, email } = body;
      if (!pairingToken || !email) return res.json({ success: false, error: 'Missing parameters' });

      const lowerEmail = String(email).toLowerCase().trim();
      const user = await User.findOne({ email: lowerEmail });
      if (!user) {
        return res.json({ success: false, error: 'Account not found' });
      }

      const storedToken = user.securePinHash || '';

      if (!storedToken) {
        return res.json({ success: true, status: 'accepted' });
      }
      if (storedToken !== pairingToken) {
        return res.json({ success: true, status: 'expired' });
      }
      return res.json({ success: true, status: 'pending' });
    }

    // ── LINK DEVICE (Accept step) ────────────────────
    if (action === 'linkDevice') {
      const {
        pairingToken, ownerEmail, newDeviceId, newDeviceName, newPlatform, appVersion,
      } = body;

      if (!pairingToken) return res.json({ success: false, error: 'Pairing token is required' });
      if (!ownerEmail) return res.json({ success: false, error: 'Owner email is required' });
      if (!newDeviceId) return res.json({ success: false, error: 'Device ID is required' });

      const lowerEmail = String(ownerEmail).toLowerCase().trim();
      const user = await User.findOne({ email: lowerEmail });
      if (!user) {
        return res.json({ success: false, error: 'Account not found' });
      }

      const storedToken = user.securePinHash || '';

      if (!storedToken) {
        return res.json({ success: false, error: 'No active pairing code. Generate a new one.' });
      }
      if (storedToken !== pairingToken) {
        return res.json({ success: false, error: 'Invalid or expired pairing code. The code may have refreshed.' });
      }

      const clientIp = getClientIp(req);
      const geo = getGeo(req);
      const now = new Date().toISOString();

      const existing = await TrustedDevice.findOne({
        userEmail: lowerEmail,
        deviceId: newDeviceId,
      });

      if (existing) {
        existing.lastLoginDate = now;
        existing.isActive = true;
        existing.isTrusted = true;
        if (newDeviceName) existing.deviceName = newDeviceName;
        if (newPlatform) existing.platform = newPlatform;
        await existing.save();
      } else {
        await TrustedDevice.create({
          userEmail: lowerEmail,
          deviceId: newDeviceId,
          deviceName: newDeviceName || 'Unknown Device',
          platform: newPlatform || 'unknown',
          firstLoginDate: now,
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
        });
      }

      user.securePinHash = '';
      await user.save();

      const userData = {
        id: user._id.toString(),
        email: user.email || '',
        username: user.username || '',
        koraId: user.koraId || '',
        fullName: user.fullName || '',
        bio: user.bio || '',
        avatarUrl: user.avatarUrl || '',
        isVerified: user.isVerified ?? true,
        profileCompleted: user.profileCompleted ?? false,
        phoneNumber: user.phoneNumber || '',
        isPremium: User.computeIsPremium ? User.computeIsPremium(user) : (user.isPremium ?? false),
        premiumExpiresAt: user.premiumExpiresAt ? new Date(user.premiumExpiresAt).toISOString() : null,
      };

      return res.json({
        success: true,
        user: userData,
        deviceId: newDeviceId,
        deviceName: newDeviceName,
        sessionInfo: {
          ip: clientIp,
          country: geo.country,
          region: geo.region,
          appVersion: appVersion || 'unknown',
          linkedAt: now,
        },
        message: 'Device linked successfully',
      });
    }

    // ── LIST DEVICES ─────────────────────────────────
    if (action === 'listDevices') {
      const { email } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();
      const devices = await TrustedDevice.find({ userEmail: lowerEmail });

      return res.json({
        success: true,
        devices: (devices || []).map((d) => ({
          id: d._id.toString(),
          deviceId: d.deviceId || '',
          deviceName: d.deviceName || 'Unknown Device',
          platform: d.platform || 'unknown',
          firstLoginDate: d.firstLoginDate || null,
          lastLoginDate: d.lastLoginDate || null,
          isActive: d.isActive ?? true,
          isTrusted: d.isTrusted ?? false,
        })),
      });
    }

    // ── LOGOUT DEVICE ─────────────────────────────────
    if (action === 'logoutDevice') {
      const { email, deviceRecordId } = body;
      if (!email || !deviceRecordId) return res.json({ success: false, error: 'Missing parameters' });

      const lowerEmail = String(email).toLowerCase().trim();
      const device = await TrustedDevice.findOne({
        userEmail: lowerEmail,
        _id: deviceRecordId,
      });

      if (!device) {
        return res.json({ success: false, error: 'Device not found' });
      }

      await TrustedDevice.deleteOne({ _id: deviceRecordId });
      return res.json({ success: true, message: 'Session terminated' });
    }

    return res.json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
