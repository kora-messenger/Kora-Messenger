const express = require('express');
const User = require('../models/User');

const router = express.Router();

// Kora Push Register — 1:1 mirror of the Base44 koraPushRegister function.
// Registers an FCM token for a user.

router.all('/', async (req, res) => {
  const params = { ...(req.query || {}), ...(req.body || {}) };
  const { email, fcmToken, platform, timestamp } = params;

  if (!email || !fcmToken) {
    return res.json({ ok: false, error: 'email and fcmToken are required' });
  }

  try {
    const normalizedEmail = String(email).toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.json({ ok: false, error: 'User not found' });
    }

    user.fcmToken = fcmToken;
    user.fcmPlatform = platform || 'android';
    user.fcmTokenUpdatedAt = new Date().toISOString();
    await user.save();

    return res.json({ ok: true, message: 'FCM token registered' });
  } catch (error) {
    console.error('[koraPushRegister] Error:', error.message || error);
    return res.json({ ok: false, error: error.message || String(error) });
  }
});

module.exports = router;
