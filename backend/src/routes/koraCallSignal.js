const express = require('express');
const CallSignal = require('../models/CallSignal');

const router = express.Router();

const groupCalls = new Map();
const CALL_EXPIRY_MS = 30 * 60 * 1000;

function cleanupExpiredCalls() {
  const now = Date.now();
  for (const [key, call] of groupCalls) {
    if (now - call.createdAt > CALL_EXPIRY_MS) {
      groupCalls.delete(key);
    }
  }
}

function safeParseList(raw) {
  if (Array.isArray(raw)) return raw;
  if (!raw) return [];
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

router.post('/', async (req, res) => {
  try {
    const body = req.body || {};
    const { action } = body;

    // ── 1:1 CALL SIGNALING ───────────────────────────────────────

    if (action === 'offer') {
      const { callId, callerId, calleeId, callType, sdp } = body;
      if (!callId || !callerId || !calleeId) {
        return res.status(400).json({ error: 'Missing callId, callerId, or calleeId' });
      }

      await CallSignal.create({
        callId,
        callerEmail: String(callerId).toLowerCase().trim(),
        calleeEmail: String(calleeId).toLowerCase().trim(),
        callType: callType || 'voice',
        offerSdp: JSON.stringify(sdp),
        answerSdp: null,
        callerCandidates: JSON.stringify([]),
        calleeCandidates: JSON.stringify([]),
        status: 'ringing',
        createdAt: new Date().toISOString(),
      });

      return res.json({ success: true, callId, status: 'ringing' });
    }

    if (action === 'answer') {
      const { callId, calleeId, sdp } = body;
      if (!callId || !calleeId) {
        return res.status(400).json({ error: 'Missing callId or calleeId' });
      }

      const record = await CallSignal.findOne({ callId });
      if (!record) {
        return res.status(404).json({ error: 'Call not found' });
      }

      record.answerSdp = JSON.stringify(sdp);
      record.status = 'connected';
      await record.save();

      return res.json({ success: true, status: 'connected' });
    }

    if (action === 'ice') {
      const { callId, from, candidate } = body;
      if (!callId || !from || !candidate) {
        return res.status(400).json({ error: 'Missing callId, from, or candidate' });
      }

      const record = await CallSignal.findOne({ callId });
      if (!record) {
        return res.status(404).json({ error: 'Call not found' });
      }

      const callerCands = safeParseList(record.callerCandidates);
      const calleeCands = safeParseList(record.calleeCandidates);

      if (from === 'caller') {
        callerCands.push(candidate);
        record.callerCandidates = JSON.stringify(callerCands);
      } else {
        calleeCands.push(candidate);
        record.calleeCandidates = JSON.stringify(calleeCands);
      }
      await record.save();

      return res.json({ success: true });
    }

    if (action === 'poll') {
      const { callId, from } = body;
      if (!callId) {
        return res.status(400).json({ error: 'Missing callId' });
      }

      const record = await CallSignal.findOne({ callId });
      if (!record) {
        return res.status(404).json({ error: 'Call not found' });
      }

      const status = record.status || 'unknown';
      const response = { status };

      if (from === 'caller') {
        if (record.answerSdp) {
          try {
            response.answer = JSON.parse(record.answerSdp);
          } catch {
            response.answer = record.answerSdp;
          }
        }
        response.calleeCandidates = safeParseList(record.calleeCandidates);
      } else {
        if (record.offerSdp) {
          try {
            response.offer = JSON.parse(record.offerSdp);
          } catch {
            response.offer = record.offerSdp;
          }
        }
        response.callerCandidates = safeParseList(record.callerCandidates);
      }

      return res.json(response);
    }

    if (action === 'status') {
      const { userId } = body;
      if (!userId) {
        return res.status(400).json({ error: 'Missing userId' });
      }

      const record = await CallSignal.findOne({
        calleeEmail: String(userId).toLowerCase().trim(),
        status: 'ringing',
      });

      if (record) {
        let offer = {};
        if (record.offerSdp) {
          try {
            offer = JSON.parse(record.offerSdp);
          } catch {
            offer = {};
          }
        }
        return res.json({
          hasIncomingCall: true,
          callId: record.callId,
          callerId: record.callerEmail,
          callType: record.callType || 'voice',
          offer,
        });
      }

      return res.json({ hasIncomingCall: false });
    }

    if (action === 'end') {
      const { callId } = body;
      if (!callId) {
        return res.status(400).json({ error: 'Missing callId' });
      }

      const record = await CallSignal.findOne({ callId });
      if (record) {
        record.status = 'ended';
        await record.save();
      }

      return res.json({ success: true, status: 'ended' });
    }

    if (action === 'reject') {
      const { callId } = body;
      if (!callId) {
        return res.status(400).json({ error: 'Missing callId' });
      }

      const record = await CallSignal.findOne({ callId });
      if (record) {
        record.status = 'rejected';
        await record.save();
      }

      return res.json({ success: true, status: 'rejected' });
    }

    // ── GROUP CALL SIGNALING ─────────────────────────────────────

    if (action === 'create_call_link') {
      const { callLinkToken, callType, requiresApproval, hostId } = body;
      if (!callLinkToken) {
        return res.status(400).json({ error: 'Missing callLinkToken' });
      }

      cleanupExpiredCalls();

      groupCalls.set(callLinkToken, {
        callLinkToken,
        callType: callType || 'voice',
        requiresApproval: requiresApproval ?? false,
        hostId: hostId || '',
        participants: [],
        waitingList: [],
        offers: new Map(),
        answers: new Map(),
        candidates: [],
        createdAt: Date.now(),
      });

      return res.json({ success: true, callLinkToken });
    }

    if (action === 'join_group_call') {
      const { callLinkToken, peerId } = body;
      if (!callLinkToken || !peerId) {
        return res.status(400).json({ error: 'Missing callLinkToken or peerId' });
      }

      cleanupExpiredCalls();

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return res.status(404).json({ error: 'Call link not found or expired' });
      }

      if (call.requiresApproval && call.participants.length > 0) {
        call.waitingList.push(peerId);
        return res.json({ status: 'waiting' });
      }

      call.participants.push(peerId);
      const peers = call.participants.filter((p) => p !== peerId);

      return res.json({
        status: 'joined',
        peers,
      });
    }

    if (action === 'group_offer') {
      const { callId, targetPeerId, sdp } = body;
      if (!targetPeerId || !sdp) {
        return res.status(400).json({ error: 'Missing targetPeerId or sdp' });
      }

      const callLinkToken = callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return res.status(404).json({ error: 'Call not found' });
      }

      call.offers.set(targetPeerId, { sdp, from: body.from || '' });
      return res.json({ success: true });
    }

    if (action === 'group_answer') {
      const { callId, targetPeerId, sdp } = body;
      if (!targetPeerId || !sdp) {
        return res.status(400).json({ error: 'Missing targetPeerId or sdp' });
      }

      const callLinkToken = callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return res.status(404).json({ error: 'Call not found' });
      }

      call.answers.set(targetPeerId, { sdp, from: body.from || '' });
      return res.json({ success: true });
    }

    if (action === 'poll_group') {
      const { callId, callLinkToken } = body;
      const token = callLinkToken || callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(token);
      if (!call) {
        return res.status(404).json({ error: 'Call not found' });
      }

      const response = {
        participants: call.participants,
        waitingList: call.waitingList,
      };

      const offers = [];
      for (const [peerId, offer] of call.offers) {
        offers.push({ peerId, ...offer });
      }
      response.offers = offers;

      const answers = [];
      for (const [peerId, answer] of call.answers) {
        answers.push({ peerId, ...answer });
      }
      response.answers = answers;

      response.candidates = call.candidates;

      return res.json(response);
    }

    if (action === 'admit_participant') {
      const { callLinkToken, participantId } = body;
      if (!callLinkToken || !participantId) {
        return res.status(400).json({ error: 'Missing callLinkToken or participantId' });
      }

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return res.status(404).json({ error: 'Call not found' });
      }

      call.waitingList = call.waitingList.filter((p) => p !== participantId);
      call.participants.push(participantId);

      return res.json({ success: true, participantId });
    }

    if (action === 'reject_participant') {
      const { callLinkToken, participantId } = body;
      if (!callLinkToken || !participantId) {
        return res.status(400).json({ error: 'Missing callLinkToken or participantId' });
      }

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return res.status(404).json({ error: 'Call not found' });
      }

      call.waitingList = call.waitingList.filter((p) => p !== participantId);

      return res.json({ success: true, participantId });
    }

    return res.status(400).json({ error: 'Unknown action' });
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
});

module.exports = router;
