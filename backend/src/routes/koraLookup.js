const express = require('express');
const User = require('../models/User');

const router = express.Router();

// 1:1 mirror of the Base44 koraLookup function — the app's
// "Add contact" username/Kora-ID search.

/// LOOKUP USER (by username or Kora ID)
router.post('/', async (req, res) => {
  const { action } = req.body || {};
  try {
    if (action === 'lookupUser') {
      const identifier = String(req.body.identifier || '').trim();
      if (!identifier) return res.json({ success: false, error: 'Identifier is required' });

      // Kora ID (KM-…) — case-insensitive upper match
      if (identifier.toUpperCase().startsWith('KM-')) {
        const user = await User.findOne({ koraId: identifier.toUpperCase() });
        return user
          ? res.json({ success: true, found: true, type: 'koraId', user: user.toClient() })
          : res.json({ success: true, found: false, type: 'koraId' });
      }

      // Username — strip @, case-insensitive (collation strength 2)
      const username = identifier.startsWith('@') ? identifier.substring(1) : identifier;
      const user = await User.findOne({ username }).collation({ locale: 'en', strength: 2 });
      return user
        ? res.json({ success: true, found: true, type: 'username', user: user.toClient() })
        : res.json({ success: true, found: false, type: 'username' });
    }

    return res.json({ success: false, error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('[koraLookup] error:', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

module.exports = router;
