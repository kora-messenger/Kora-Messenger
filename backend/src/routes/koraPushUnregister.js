const express = require('express');
const User = require('../models/User');

const router = express.Router();

// Kora Push Unregister — 1:1 mirror of the Base44 koraPushUnregister function.
// Unregisters an FCM token for a user on logout.

router.all('/', async (req, res) => {
  const params = { ...(req.query || {}), ...(req.body || {}) };
  const { email, fcmToken } = params;

  if (!email) {
    return res.json({ ok: false, error: 'email is required' });
  }

  try {
    const normalizedEmail = String(email).toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.json({ ok: false, error: 'User not found' });
    }

    // Only clear if the token matches (avoid clearing a newer token)
    if (user.fcmToken === fcmToken) {
      user.fcmToken = null;
      user.fcmPlatform = null;
      user.fcmTokenUpdatedAt = null;
      await user.save();
    }

    return res.json({ ok: true, message: 'FCM token unregistered' });
  } catch (error) {
    console.error('[koraPushUnregister] Error:', error.message || error);
    return res.json({ ok: false, error: error.message || String(error) });
  }
});

module.exports = router;
