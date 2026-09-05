const express = require('express');
const User = require('../models/User');

const router = express.Router();

// Kora E2EE Keys — 1:1 mirror of the Base44 koraE2eeKeys function.
// Allows users to publish and lookup public E2EE encryption/signing keys.

router.all('/', async (req, res) => {
  try {
    const params = { ...(req.query || {}), ...(req.body || {}) };
    const { action, email, publicKey, signingKey } = params;

    if (action === 'publish') {
      const normalizedEmail = String(email || '').toLowerCase().trim();
      const user = await User.findOne({ email: normalizedEmail });
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      user.publicKey = publicKey || '';
      user.signingKey = signingKey || '';
      await user.save();

      return res.json({ success: true, message: 'Public keys published' });
    }

    if (action === 'lookup') {
      const { lookupKey, lookupValue } = params;
      const query = {};

      if (lookupKey === 'email') {
        query.email = String(lookupValue || '').toLowerCase().trim();
      } else if (lookupKey === 'koraId') {
        query.koraId = String(lookupValue || '').trim();
      } else {
        query.email = String(email || '').toLowerCase().trim();
      }

      const user = await User.findOne(query);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      return res.json({
        email: user.email,
        fullName: user.fullName || '',
        publicKey: user.publicKey || '',
        signingKey: user.signingKey || '',
      });
    }

    return res.status(400).json({ error: 'Invalid action. Use "publish" or "lookup".' });
  } catch (error) {
    console.error('[koraE2eeKeys] Error:', error);
    return res.status(500).json({ error: error.message || 'Internal error' });
  }
});

module.exports = router;
