const express = require('express');
const User = require('../models/User');

const router = express.Router();

// The app POSTs {email} (no action) — used by the chat screen and the
// chats tab to fetch the recipient's live profile.
router.post('/', async (req, res) => {
  const email = String((req.body || {}).email || '').toLowerCase().trim();
  try {
    if (!email) return res.json({ success: false, error: 'Email is required' });
    const user = await User.findOne({ email });
    return user
      ? res.json({ success: true, found: true, user: user.toClient() })
      : res.json({ success: true, found: false });
  } catch (err) {
    console.error('[koraLookupByEmail] error:', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

module.exports = router;
