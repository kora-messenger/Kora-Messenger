import { Router } from 'express';
import CallSignal from '../models/CallSignal.js';

const router = Router();

router.post('/', async (req, res) => {
  const { action } = req.body;

  try {
    // ── OFFER ──
    if (action === 'offer') {
      const { callId, callerEmail, calleeEmail, offerSdp, callType } = req.body;
      await CallSignal.create({ callId, callerEmail, calleeEmail, offerSdp, callType, status: 'ringing' });
      return res.json({ success: true });
    }

    // ── ANSWER ──
    if (action === 'answer') {
      const { callId, answerSdp } = req.body;
      await CallSignal.updateOne({ callId }, { answerSdp, status: 'connected' });
      return res.json({ success: true });
    }

    // ── ICE ──
    if (action === 'ice') {
      const { callId, candidates, from } = req.body;
      const call = await CallSignal.findOne({ callId });
      if (!call) return res.status(404).json({ error: 'Call not found' });
      const field = from === 'caller' ? 'callerCandidates' : 'calleeCandidates';
      call[field].push(...(Array.isArray(candidates) ? candidates : [candidates]));
      await call.save();
      return res.json({ success: true });
    }

    // ── POLL ──
    if (action === 'poll') {
      const { callId } = req.body;
      const call = await CallSignal.findOne({ callId });
      if (!call) return res.status(404).json({ error: 'Call not found' });
      return res.json({
        status: call.status,
        offerSdp: call.offerSdp,
        answerSdp: call.answerSdp,
        callerCandidates: call.callerCandidates,
        calleeCandidates: call.calleeCandidates,
      });
    }

    // ── END ──
    if (action === 'end') {
      const { callId } = req.body;
      await CallSignal.updateOne({ callId }, { status: 'ended' });
      return res.json({ success: true });
    }

    // ── REJECT ──
    if (action === 'reject') {
      const { callId } = req.body;
      await CallSignal.updateOne({ callId }, { status: 'rejected' });
      return res.json({ success: true });
    }

    // ── STATUS ──
    if (action === 'status') {
      const { callId } = req.body;
      const call = await CallSignal.findOne({ callId });
      if (!call) return res.status(404).json({ error: 'Call not found' });
      return res.json({ status: call.status });
    }

    // ── CLEANUP ──
    if (action === 'cleanup') {
      const { callId } = req.body;
      await CallSignal.deleteOne({ callId });
      return res.json({ success: true });
    }

    return res.status(400).json({ error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('Calls route error:', err);
    return res.status(500).json({ error: 'Internal server error', detail: err.message });
  }
});

export default router;
