/**
 * Kora Call Signaling — WebRTC signaling server for 1:1 and group calls.
 *
 * Actions:
 *   offer          — Caller posts SDP offer + starts a call
 *   answer         — Callee posts SDP answer
 *   ice            — Either side posts ICE candidates
 *   poll           — Either side polls for updates (answer, candidates, status)
 *   status         — Callee polls for incoming calls
 *   end            — Either side ends the call
 *   reject         — Callee rejects the call
 *   group_offer    — Group call: peer posts SDP offer to target
 *   group_answer   — Group call: peer posts SDP answer to target
 *   join_group_call — Join a group call via link token
 *   poll_group     — Poll for group call updates
 *   create_call_link — Create a call link token
 *   admit_participant — Host admits from lobby
 *   reject_participant — Host rejects from lobby
 *
 * Uses the CallSignal entity for 1:1 calls.
 * Group calls use in-memory state (sufficient for call duration).
 */

import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}

// ── In-memory group call state (survives for call duration) ──────────
interface GroupCallState {
  callLinkToken: string;
  callType: string;
  requiresApproval: boolean;
  hostId: string;
  participants: string[];
  waitingList: string[];
  offers: Map<string, any>; // targetPeerId -> { sdp, from }
  answers: Map<string, any>; // targetPeerId -> { sdp, from }
  candidates: any[];
  createdAt: number;
}

const groupCalls = new Map<string, GroupCallState>();
const CALL_EXPIRY_MS = 30 * 60 * 1000; // 30 min

// Clean up expired group calls
function cleanupExpiredCalls() {
  const now = Date.now();
  for (const [key, call] of groupCalls) {
    if (now - call.createdAt > CALL_EXPIRY_MS) {
      groupCalls.delete(key);
    }
  }
}

// Candidate lists are stored as JSON strings (entity fields are string-typed).
function safeParseList(raw: any): any[] {
  if (Array.isArray(raw)) return raw;
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    });
  }

  try {
    const body = await req.json();
    const { action } = body;

    const client = createClientFromRequest(req);
    const db = client.asServiceRole;

    // ── 1:1 CALL SIGNALING ───────────────────────────────────────

    if (action === 'offer') {
      const { callId, callerId, calleeId, callType, sdp } = body;
      if (!callId || !callerId || !calleeId) {
        return jsonResponse({ error: 'Missing callId, callerId, or calleeId' }, 400);
      }

      // Create call signal record
      await db.entities.CallSignal.create({
        callId,
        callerEmail: callerId,
        calleeEmail: calleeId,
        callType: callType || 'voice',
        offerSdp: JSON.stringify(sdp),
        answerSdp: null,
        callerCandidates: JSON.stringify([]),
        calleeCandidates: JSON.stringify([]),
        status: 'ringing',
        createdAt: new Date().toISOString(),
      });

      return jsonResponse({ success: true, callId, status: 'ringing' });
    }

    if (action === 'answer') {
      const { callId, calleeId, sdp } = body;
      if (!callId || !calleeId) {
        return jsonResponse({ error: 'Missing callId or calleeId' }, 400);
      }

      // Find the call signal record and update with answer
      const records = await db.entities.CallSignal.filter(
        { callId },
        undefined,
        1
      );

      if (!records || records.length === 0) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      const record = records[0];
      await db.entities.CallSignal.update(record.id, {
        answerSdp: JSON.stringify(sdp),
        status: 'connected',
      });

      return jsonResponse({ success: true, status: 'connected' });
    }

    if (action === 'ice') {
      const { callId, from, candidate } = body;
      if (!callId || !from || !candidate) {
        return jsonResponse({ error: 'Missing callId, from, or candidate' }, 400);
      }

      const records = await db.entities.CallSignal.filter(
        { callId },
        undefined,
        1
      );

      if (!records || records.length === 0) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      const record = records[0];
      const data = record.data ?? record;
      const callerCands = safeParseList(data.callerCandidates);
      const calleeCands = safeParseList(data.calleeCandidates);

      if (from === 'caller') {
        callerCands.push(candidate);
        await db.entities.CallSignal.update(record.id, {
          callerCandidates: JSON.stringify(callerCands),
        });
      } else {
        calleeCands.push(candidate);
        await db.entities.CallSignal.update(record.id, {
          calleeCandidates: JSON.stringify(calleeCands),
        });
      }

      return jsonResponse({ success: true });
    }

    if (action === 'poll') {
      const { callId, from } = body;
      if (!callId) {
        return jsonResponse({ error: 'Missing callId' }, 400);
      }

      const records = await db.entities.CallSignal.filter(
        { callId },
        undefined,
        1
      );

      if (!records || records.length === 0) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      const record = records[0];
      const data = record.data ?? record;
      const status = data.status || 'unknown';

      // Return relevant data based on who's polling
      const response: any = { status };

      if (from === 'caller') {
        // Caller wants the answer and callee candidates
        if (data.answerSdp) {
          response.answer = JSON.parse(data.answerSdp);
        }
        response.calleeCandidates = safeParseList(data.calleeCandidates);
      } else {
        // Callee wants the offer and caller candidates
        if (data.offerSdp) {
          response.offer = JSON.parse(data.offerSdp);
        }
        response.callerCandidates = safeParseList(data.callerCandidates);
      }

      return jsonResponse(response);
    }

    if (action === 'status') {
      // Check if user has an incoming call
      const { userId } = body;
      if (!userId) {
        return jsonResponse({ error: 'Missing userId' }, 400);
      }

      const records = await db.entities.CallSignal.filter(
        { calleeEmail: userId, status: 'ringing' },
        undefined,
        1
      );

      if (records && records.length > 0) {
        const record = records[0];
        const data = record.data ?? record;
        return jsonResponse({
          hasIncomingCall: true,
          callId: data.callId,
          callerId: data.callerEmail,
          callType: data.callType || 'voice',
          offer: data.offerSdp ? JSON.parse(data.offerSdp) : {},
        });
      }

      return jsonResponse({ hasIncomingCall: false });
    }

    if (action === 'end') {
      const { callId } = body;
      if (!callId) {
        return jsonResponse({ error: 'Missing callId' }, 400);
      }

      const records = await db.entities.CallSignal.filter(
        { callId },
        undefined,
        1
      );

      if (records && records.length > 0) {
        await db.entities.CallSignal.update(records[0].id, {
          status: 'ended',
        });
      }

      return jsonResponse({ success: true, status: 'ended' });
    }

    if (action === 'reject') {
      const { callId } = body;
      if (!callId) {
        return jsonResponse({ error: 'Missing callId' }, 400);
      }

      const records = await db.entities.CallSignal.filter(
        { callId },
        undefined,
        1
      );

      if (records && records.length > 0) {
        await db.entities.CallSignal.update(records[0].id, {
          status: 'rejected',
        });
      }

      return jsonResponse({ success: true, status: 'rejected' });
    }

    // ── GROUP CALL SIGNALING ─────────────────────────────────────

    if (action === 'create_call_link') {
      const { callLinkToken, callType, requiresApproval } = body;
      if (!callLinkToken) {
        return jsonResponse({ error: 'Missing callLinkToken' }, 400);
      }

      cleanupExpiredCalls();

      groupCalls.set(callLinkToken, {
        callLinkToken,
        callType: callType || 'voice',
        requiresApproval: requiresApproval ?? false,
        hostId: body.hostId || '',
        participants: [],
        waitingList: [],
        offers: new Map(),
        answers: new Map(),
        candidates: [],
        createdAt: Date.now(),
      });

      return jsonResponse({ success: true, callLinkToken });
    }

    if (action === 'join_group_call') {
      const { callLinkToken, peerId } = body;
      if (!callLinkToken || !peerId) {
        return jsonResponse({ error: 'Missing callLinkToken or peerId' }, 400);
      }

      cleanupExpiredCalls();

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return jsonResponse({ error: 'Call link not found or expired' }, 404);
      }

      if (call.requiresApproval && call.participants.length > 0) {
        // Add to waiting list if approval required and not the host
        call.waitingList.push(peerId);
        return jsonResponse({ status: 'waiting' });
      }

      // Auto-admit
      call.participants.push(peerId);

      // Return current peers (excluding self)
      const peers = call.participants.filter((p) => p !== peerId);

      return jsonResponse({
        status: 'joined',
        peers,
      });
    }

    if (action === 'group_offer') {
      const { callId, targetPeerId, sdp } = body;
      if (!targetPeerId || !sdp) {
        return jsonResponse({ error: 'Missing targetPeerId or sdp' }, 400);
      }

      const callLinkToken = callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      call.offers.set(targetPeerId, { sdp, from: body.from || '' });
      return jsonResponse({ success: true });
    }

    if (action === 'group_answer') {
      const { callId, targetPeerId, sdp } = body;
      if (!targetPeerId || !sdp) {
        return jsonResponse({ error: 'Missing targetPeerId or sdp' }, 400);
      }

      const callLinkToken = callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      call.answers.set(targetPeerId, { sdp, from: body.from || '' });
      return jsonResponse({ success: true });
    }

    if (action === 'poll_group') {
      const { callId, callLinkToken } = body;
      const token = callLinkToken || callId?.replace('group_link_', '') || '';
      const call = groupCalls.get(token);
      if (!call) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      const response: any = {
        participants: call.participants,
        waitingList: call.waitingList,
      };

      // Return any pending offers/answers for this peer
      const offers: any[] = [];
      for (const [peerId, offer] of call.offers) {
        offers.push({ peerId, ...offer });
      }
      response.offers = offers;

      const answers: any[] = [];
      for (const [peerId, answer] of call.answers) {
        answers.push({ peerId, ...answer });
      }
      response.answers = answers;

      response.candidates = call.candidates;

      return response;
    }

    if (action === 'admit_participant') {
      const { callLinkToken, participantId } = body;
      if (!callLinkToken || !participantId) {
        return jsonResponse({ error: 'Missing callLinkToken or participantId' }, 400);
      }

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      call.waitingList = call.waitingList.filter((p) => p !== participantId);
      call.participants.push(participantId);

      return jsonResponse({ success: true, participantId });
    }

    if (action === 'reject_participant') {
      const { callLinkToken, participantId } = body;
      if (!callLinkToken || !participantId) {
        return jsonResponse({ error: 'Missing callLinkToken or participantId' }, 400);
      }

      const call = groupCalls.get(callLinkToken);
      if (!call) {
        return jsonResponse({ error: 'Call not found' }, 404);
      }

      call.waitingList = call.waitingList.filter((p) => p !== participantId);

      return jsonResponse({ success: true, participantId });
    }

    // ── Unknown action ───────────────────────────────────────────
    return jsonResponse({ error: 'Unknown action' }, 400);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
