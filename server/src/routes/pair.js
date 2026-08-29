import { Router } from 'express';
import crypto from 'node:crypto';
import PairToken from '../models/PairToken.js';
import KoraUser from '../models/KoraUser.js';

const router = Router();

router.post('/', async (req, res) => {
  const { action } = req.body;

  try {
    // ── REQUEST PAIR ──
    if (action === 'requestPair') {
      const pairingToken = crypto.randomUUID();
      const timestamp = Date.now();
      const qrData = `kora-web-pair:${pairingToken}:${timestamp}`;
      await PairToken.create({ pairingToken, qrData, status: 'pending' });
      return res.json({ success: true, pairingToken, qrData });
    }

    // ── POLL PAIR ──
    if (action === 'pollPair') {
      const { pairingToken } = req.body;
      const token = await PairToken.findOne({ pairingToken });
      if (!token) {
        return res.json({ status: 'expired' });
      }
      if (token.status === 'accepted' && token.userEmail) {
        const user = await KoraUser.findOne({ email: token.userEmail }).select('-passwordHash -securePinHash -signingKey');
        return res.json({ status: 'accepted', user });
      }
      return res.json({ status: 'pending' });
    }

    // ── ACCEPT PAIR ──
    if (action === 'acceptPair') {
      const { pairingToken, userEmail, deviceId } = req.body;
      const token = await PairToken.findOne({ pairingToken, status: 'pending' });
      if (!token) {
        return res.status(404).json({ error: 'Token not found or already used' });
      }
      const user = await KoraUser.findOne({ email: userEmail }).select('-passwordHash -securePinHash -signingKey');
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      token.status = 'accepted';
      token.userEmail = userEmail;
      token.deviceId = deviceId;
      await token.save();
      return res.json({ success: true, user });
    }

    // ── EXTEND TOKEN ──
    if (action === 'extendToken') {
      const { pairingToken } = req.body;
      const token = await PairToken.findOne({ pairingToken });
      if (!token) {
        return res.status(404).json({ error: 'Token not found' });
      }
      token.createdAt = new Date();
      await token.save();
      return res.json({ success: true });
    }

    return res.status(400).json({ error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('Pair route error:', err);
    return res.status(500).json({ error: 'Internal server error', detail: err.message });
  }
});

export default router;
