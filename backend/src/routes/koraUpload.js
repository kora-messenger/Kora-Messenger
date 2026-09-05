const express = require('express');

const router = express.Router();

// Kora Upload — 1:1 mirror of the Base44 koraUpload function.
//
// The app sends base64 image data and receives a data URL back, which
// it then persists (avatar → KoraUser.avatarUrl, media → message
// mediaUrl). No server-side storage is involved — the function is
// stateless, which is why the DB never holds the raw bytes.
//
// Actions:
// 1. "uploadAvatar" — profile photos (profile setup + edit profile)
// 2. "uploadMedia"  — chat attachments (currently unused by the app,
//                     kept for contract parity)

router.post('/', (req, res) => {
  const body = req.body || {};
  const { action } = body;

  try {
    // ── UPLOAD AVATAR ─────────────────────────────────
    if (action === 'uploadAvatar') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) {
        return res.json({ success: false, error: 'No image data provided' });
      }
      const mimeType = fileType || 'image/jpeg';
      return res.json({
        success: true,
        url: `data:${mimeType};base64,${imageBase64}`,
      });
    }

    // ── UPLOAD MEDIA (for chat attachments) ───────────
    if (action === 'uploadMedia') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) {
        return res.json({ success: false, error: 'No media data provided' });
      }
      const mimeType = fileType || 'application/octet-stream';
      return res.json({
        success: true,
        url: `data:${mimeType};base64,${imageBase64}`,
      });
    }

    return res.json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
