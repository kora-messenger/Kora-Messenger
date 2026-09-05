const express = require('express');
const UserSettings = require('../models/UserSettings');

const router = express.Router();

// Kora Settings Sync — 1:1 mirror of the Base44 koraSettingsSync function.
// Telegram-style cloud settings: every user preference is stored as a
// merged JSON blob keyed by userEmail. Log in on any device and all
// settings appear — no restore flow needed.
//
// Actions:
// 1. "save" — merge {settings: {key: {_t, _v}}} into the stored blob
//             (per-key last write wins across devices)
// 2. "load" — return the merged settings blob + updatedAt

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action, userEmail } = body;

  if (!userEmail) {
    return res.status(400).json({ success: false, error: 'userEmail is required' });
  }
  const owner = String(userEmail).toLowerCase().trim();

  try {
    // ── SAVE (merge) ────────────────────────────────────
    // Client pushes { settings: { key: { _t: 'b'|'i'|'d'|'s'|'l', _v } } } —
    // each key is merged into the stored blob (per-key last write wins).
    if (action === 'save') {
      const settings = body.settings;
      if (!settings || typeof settings !== 'object') {
        return res.status(400).json({ success: false, error: 'settings object required' });
      }

      const existing = await UserSettings.findOne({ userEmail: owner });

      let merged = {};
      if (existing) {
        try {
          merged = JSON.parse(existing.settingsJson || '{}');
        } catch {
          merged = {};
        }
        Object.assign(merged, settings);
        existing.settingsJson = JSON.stringify(merged);
        existing.keyCount = Object.keys(merged).length;
        existing.updatedAt = new Date().toISOString();
        existing.deviceName = body.deviceName || existing.deviceName;
        await existing.save();
      } else {
        merged = { ...settings };
        await UserSettings.create({
          userEmail: owner,
          settingsJson: JSON.stringify(merged),
          keyCount: Object.keys(merged).length,
          updatedAt: new Date().toISOString(),
          deviceName: body.deviceName || 'unknown',
        });
      }

      return res.json({
        success: true,
        updatedAt: new Date().toISOString(),
        keyCount: Object.keys(merged).length,
      });
    }

    // ── LOAD ───────────────────────────────────────────
    if (action === 'load') {
      const existing = await UserSettings.findOne({ userEmail: owner });
      if (!existing) {
        return res.json({ success: true, settings: {}, updatedAt: null });
      }
      let settings = {};
      try {
        settings = JSON.parse(existing.settingsJson || '{}');
      } catch {
        settings = {};
      }
      return res.json({
        success: true,
        settings,
        updatedAt: existing.updatedAt,
      });
    }

    return res.status(400).json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
