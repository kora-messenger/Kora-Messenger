import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

// ─────────────────────────────────────────────────────────────
//  Kora Automated Detection System
//  Monitors user activity and automatically suspends accounts that
//  violate community guidelines. Notifies the owner with details.
//
//  Domain-swappable config — change OWNER_EMAIL when you get a .com
// ─────────────────────────────────────────────────────────────
const OWNER_EMAIL = 'ijeziegoodluck@gmail.com';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ── Detection pattern libraries ──────────────────────────────

const CHILD_SAFETY_PATTERNS = [
  /child\s+(?:porn|sexual|abuse|exploit|nude)/i,
  /underage\s+(?:girl|boy|kid|child|minor)/i,
  /(?:csam|csem)/i,
  /groom(?:ing)?\s+(?:a\s+)?(?:child|minor|kid)/i,
  /(?:loli(?:con)?|shota(?:con)?)/i,
];

const FRAUD_PATTERNS = [
  /(?:investment\s+(?:opportunity|scheme|returns|profit|guaranteed))/i,
  /(?:double\s+(?:your|ur)\s+(?:money|crypto|bitcoin|eth|usdt))/i,
  /(?:forex\s+(?:trading|investment|signals|broker))/i,
  /(?:send\s+\$?\d+\s+(?:and|to)\s+(?:get|receive|double|earn))/i,
  /(?:sugar\s+(?:daddy|mommy|mummy))/i,
  /(?:crypto\s+(?:giveaway|airdrop|doubler|mining))/i,
  /(?:advance\s+fee|upfront\s+(?:payment|fee))/i,
  /(?:naira\s+(?:doubling|multiplying|investment))/i,
  /(?:make\s+(?:money|₦|\$)\s+(?:fast|quick|easy|now|today|instantly))/i,
];

const PHISHING_PATTERNS = [
  /(?:enter\s+(?:your|ur)\s+(?:password|pin|otp|code|cvv))/i,
  /(?:verify\s+(?:your|ur)\s+(?:account|identity|email))/i,
  /(?:click\s+(?:here|this\s+link)\s+to\s+(?:verify|confirm|update|secure))/i,
  /(?:your\s+(?:account|wallet)\s+(?:will\s+be|is\s+going\s+to\s+be)\s+(?:closed|suspended|blocked|deleted))/i,
  /(?:kora\s+(?:support|team|security)\s+(?:has\s+detected|noticed|found))/i,
  /(?:suspicious\s+(?:activity|login|attempt)\s+(?:on|detected)\s+(?:your|ur)\s+(?:account|device))/i,
  /(?:update\s+(?:your|ur)\s+(?:payment|billing|card)\s+(?:info|information|details))/i,
];

const MALWARE_PATTERNS = [
  /\.(?:apk|exe|bat|cmd|scr|vbs|dll|jar|msi|ps1)(?:\s|$|\?)/i,
  /(?:download\s+(?:this|the)\s+(?:file|app|tool|software))/i,
  /(?:free\s+(?:hack|cheat|crack|mod|patch|keygen))/i,
  /(?:remote\s+(?:access|control)\s+(?:tool|trojan|rat))/i,
];

const HARASSMENT_PATTERNS = [
  /(?:i\s+(?:will|'ll|won't)\s+(?:find|hunt|come\s+for|get\s+you|hurt\s+(?:you|your|ur)))/i,
  /(?:you\s+(?:will|won't|are\s+going\s+to)\s+(?:die|suffer|pay|regret))/i,
  /(?:kill\s+(?:yourself|urself|yaself|you))/i,
  /(?:i\s+know\s+where\s+you\s+(?:live|stay|work|school))/i,
];

const IMPERSONATION_PATTERNS = [
  /(?:i\s+am\s+(?:kora\s+)?(?:support|admin|moderator|staff|official))/i,
  /(?:this\s+is\s+kora\s+(?:support|team|security|verification))/i,
  /(?:kora\s+(?:team|support|security)\s+(?:message|request|ask))/i,
];

const HATE_SPEECH_PATTERNS = [
  /(?:subhuman|dehumaniz(?:e|ed)|vermin|cockroach|parasite)/i,
  /(?:ethnic\s+(?:cleansing|genocide|purging))/i,
  /(?:kill\s+all\s+(?:them|those|these|the)\s+\w+)/i,
];

const ILLEGAL_PATTERNS = [
  /(?:buy|sell|trade|ship)\s+(?:drugs?|cocaine|weed|crack|heroin|meth|fentanyl|pills)/i,
  /(?:weapon|gun|firearm|rifle|pistol)\s+(?:for\s+sale|selling|buying|trade)/i,
  /(?:human\s+(?:trafficking|smuggling))/i,
  /(?:money\s+laundering|wash\s+money)/i,
  /(?:counterfeit|fake\s+(?:money|naira|dollar|currency))/i,
  /(?:stolen\s+(?:card|credit\s+card|identity|phone|laptop))/i,
];

const SPAM_PATTERNS = [
  /(?:(?:buy|sell|deal|offer|discount|promo|prize|winner|congratulations).*){3,}/i,
  /(?:click\s+(?:here|below|link).*){2,}/i,
  /(?:follow\s+me|subscribe|check\s+my\s+profile|visit\s+my\s+(?:page|channel|site))/i,
];

interface DetectionResult {
  flags: string[];
  severity: number;
  detectionType: string;
  detectionDetails: string;
}

function analyzeContent(content: string, recipientCount?: number): DetectionResult {
  const lower = (content || '').toLowerCase().trim();
  const flags: string[] = [];
  let severity = 0;
  let detectionType = 'other';
  let detectionDetails = '';

  // Child safety — severity 10, immediate permanent
  for (const p of CHILD_SAFETY_PATTERNS) {
    if (p.test(lower)) {
      flags.push('child_safety_violation');
      severity = 10;
      detectionType = 'child_safety';
      detectionDetails = 'CHILD SAFETY VIOLATION: Immediate suspension triggered';
    }
  }

  // Phishing — severity 5
  for (const p of PHISHING_PATTERNS) {
    if (p.test(lower)) {
      flags.push('phishing_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'phishing'; detectionDetails = 'Phishing/credential theft attempt detected'; }
    }
  }

  // Malware — severity 5
  for (const p of MALWARE_PATTERNS) {
    if (p.test(lower)) {
      flags.push('malware_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'malware'; detectionDetails = 'Potential malware/malicious file sharing detected'; }
    }
  }

  // Impersonation — severity 5
  for (const p of IMPERSONATION_PATTERNS) {
    if (p.test(lower)) {
      flags.push('impersonation_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'impersonation'; detectionDetails = 'Impersonation of Kora official account detected'; }
    }
  }

  // Hate speech — severity 6
  for (const p of HATE_SPEECH_PATTERNS) {
    if (p.test(lower)) {
      flags.push('hate_speech');
      severity = Math.max(severity, 6);
      if (detectionType === 'other') { detectionType = 'hate_speech'; detectionDetails = 'Hate speech / targeted abuse detected'; }
    }
  }

  // Illegal activity — severity 6
  for (const p of ILLEGAL_PATTERNS) {
    if (p.test(lower)) {
      flags.push('illegal_activity');
      severity = Math.max(severity, 6);
      if (detectionType === 'other') { detectionType = 'illegal_activity'; detectionDetails = 'Illegal activity detected in message content'; }
    }
  }

  // Harassment — severity 4
  for (const p of HARASSMENT_PATTERNS) {
    if (p.test(lower)) {
      flags.push('harassment_pattern');
      severity = Math.max(severity, 4);
      if (detectionType === 'other') { detectionType = 'harassment'; detectionDetails = 'Harassment/threatening content detected'; }
    }
  }

  // Fraud — severity 4
  for (const p of FRAUD_PATTERNS) {
    if (p.test(lower)) {
      flags.push('fraud_pattern');
      severity = Math.max(severity, 4);
      if (detectionType === 'other') { detectionType = 'fraud'; detectionDetails = 'Fraudulent/scam content detected in message'; }
    }
  }

  // Spam — severity 2 (or 3 with mass messaging)
  if (recipientCount && recipientCount > 50) {
    flags.push('mass_messaging');
    severity = Math.max(severity, 3);
    if (detectionType === 'other') { detectionType = 'spam'; detectionDetails = `Message sent to ${recipientCount} recipients simultaneously`; }
  }

  for (const p of SPAM_PATTERNS) {
    if (p.test(lower)) {
      flags.push('spam_pattern');
      severity = Math.max(severity, 2);
      if (detectionType === 'other') { detectionType = 'spam'; detectionDetails = 'Promotional spam pattern detected'; }
    }
  }

  return { flags, severity, detectionType, detectionDetails };
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── ANALYZE MESSAGE ──────────────────────────────────
    if (action === 'analyzeMessage') {
      const { userEmail, userKoraId, username, messageContent, recipientCount } = body;
      if (!userEmail || !messageContent) {
        return jsonResponse({ suspended: false, flags: [] });
      }

      const result = analyzeContent(messageContent, recipientCount);

      // Severity thresholds: 3-4 = 24h, 5-6 = 7d, 7-9 = 30d, 10+ = permanent
      if (result.severity >= 3 && result.flags.length > 0) {
        const users = await db.entities.KoraUser.filter({ email: userEmail });
        if (!users || users.length === 0) {
          return jsonResponse({ suspended: false, flags: result.flags, severity: result.severity, error: 'User not found' });
        }

        const user = users[0];
        const userData = user.data || {};
        if (userData.isSuspended) {
          return jsonResponse({ suspended: true, alreadySuspended: true, flags: result.flags, message: 'User is already suspended' });
        }

        const now = new Date();
        let suspensionHours = 24;
        let isPermanent = false;

        if (result.severity >= 10) isPermanent = true;
        else if (result.severity >= 7) suspensionHours = 720;
        else if (result.severity >= 5) suspensionHours = 168;

        const expiresAt = isPermanent ? 'permanent' : new Date(now.getTime() + suspensionHours * 3600000).toISOString();

        await db.entities.KoraUser.update(user.id, {
          ...userData,
          isSuspended: true,
          suspensionReason: result.detectionDetails,
          suspensionTimestamp: now.toISOString(),
          suspensionExpiresAt: expiresAt,
          suspensionAppealStatus: 'none',
        });

        await db.entities.SuspensionRecord.create({
          userEmail,
          userKoraId: userKoraId || userData.koraId || '',
          username: username || userData.username || '',
          detectionType: result.detectionType,
          detectionDetails: result.detectionDetails,
          reason: result.detectionDetails,
          suspendedAt: now.toISOString(),
          expiresAt,
          status: 'active',
          autoDetected: true,
          suspendedBy: 'automated_detection_system',
          ownerNotified: false,
          resolved: false,
          appealDecision: 'none',
          appealMessage: '',
          appealSubmittedAt: '',
        });

        return jsonResponse({
          suspended: true,
          flags: result.flags,
          severity: result.severity,
          detectionType: result.detectionType,
          isPermanent,
          expiresAt,
          message: isPermanent
            ? 'Account permanently suspended due to severe community guidelines violation'
            : `Account suspended for ${suspensionHours} hours`,
        });
      }

      return jsonResponse({
        suspended: false,
        flags: result.flags,
        severity: result.severity,
        message: result.flags.length === 0 ? 'No violations detected' : 'Minor flags — no suspension',
      });
    }

    // ── CHECK SUSPENSION STATUS ──────────────────────────
    if (action === 'checkSuspensionStatus') {
      const { email } = body;
      if (!email) return jsonResponse({ suspended: false });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) return jsonResponse({ suspended: false });

      const user = users[0];
      const userData = user.data || {};

      if (!userData.isSuspended) return jsonResponse({ suspended: false });

      // Check if expired
      if (userData.suspensionExpiresAt && userData.suspensionExpiresAt !== 'permanent') {
        const expiresAt = new Date(userData.suspensionExpiresAt);
        const now = new Date();
        if (now > expiresAt) {
          // Reactivate
          await db.entities.KoraUser.update(user.id, {
            ...userData,
            isSuspended: false,
            suspensionReason: '',
            suspensionExpiresAt: '',
            suspensionAppealStatus: 'none',
          });

          const records = await db.entities.SuspensionRecord.filter({ userEmail: email, status: 'active' });
          for (const r of (records || [])) {
            await db.entities.SuspensionRecord.update(r.id, { ...r.data, status: 'expired', resolved: true });
          }

          return jsonResponse({ suspended: false, wasSuspended: true });
        }

        const hoursRemaining = Math.ceil((expiresAt.getTime() - now.getTime()) / 3600000);
        return jsonResponse({
          suspended: true,
          reason: userData.suspensionReason || 'Your account has been suspended for violating Kora Messenger Community Guidelines.',
          expiresAt: userData.suspensionExpiresAt,
          hoursRemaining,
          isPermanent: false,
          appealStatus: userData.suspensionAppealStatus || 'none',
        });
      }

      // Permanent suspension
      return jsonResponse({
        suspended: true,
        reason: userData.suspensionReason || 'Your account has been permanently suspended for severe violations of Kora Messenger Community Guidelines.',
        expiresAt: 'permanent',
        isPermanent: true,
        appealStatus: userData.suspensionAppealStatus || 'none',
      });
    }

    // ── SUBMIT APPEAL ─────────────────────────────────────
    if (action === 'submitAppeal') {
      const { email, appealMessage } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) return jsonResponse({ success: false, error: 'User not found' });

      const user = users[0];
      const userData = user.data || {};

      if (!userData.isSuspended) return jsonResponse({ success: false, error: 'Account is not suspended' });

      if (userData.suspensionAppealStatus === 'pending') {
        return jsonResponse({ success: false, error: 'You have already submitted an appeal. Please wait for a response.' });
      }

      if (userData.suspensionAppealStatus === 'denied') {
        return jsonResponse({ success: false, error: 'Your appeal has been denied. You must wait for your suspension to expire.' });
      }

      const now = new Date().toISOString();

      // Update user appeal status
      await db.entities.KoraUser.update(user.id, {
        ...userData,
        suspensionAppealStatus: 'pending',
      });

      // Update suspension record
      const records = await db.entities.SuspensionRecord.filter({ userEmail: email, status: 'active' });
      for (const r of (records || [])) {
        await db.entities.SuspensionRecord.update(r.id, {
          ...r.data,
          status: 'appealed',
          appealMessage: appealMessage || '',
          appealSubmittedAt: now,
        });
      }

      return jsonResponse({
        success: true,
        message: 'Your appeal has been submitted. Please allow up to 24 hours for a response.',
      });
    }

    // ── GET OWNER SUSPENSIONS ─────────────────────────────
    if (action === 'getOwnerSuspensions') {
      const { ownerEmail } = body;
      if (ownerEmail !== OWNER_EMAIL) {
        return jsonResponse({ authorized: false, message: 'Only the Kora owner can view suspensions' });
      }

      const records = await db.entities.SuspensionRecord.filter({ resolved: false });
      return jsonResponse({
        authorized: true,
        suspensions: (records || []).map(r => ({ id: r.id, ...r.data })),
        count: (records || []).length,
      });
    }

    // ── RESOLVE APPEAL ────────────────────────────────────
    if (action === 'resolveAppeal') {
      const { ownerEmail, suspensionRecordId, decision } = body;
      if (ownerEmail !== OWNER_EMAIL) {
        return jsonResponse({ authorized: false, message: 'Only the Kora owner can resolve appeals' });
      }

      if (!['approved', 'denied'].includes(decision)) {
        return jsonResponse({ error: 'Invalid decision' });
      }

      const record = await db.entities.SuspensionRecord.get(suspensionRecordId);
      const recordData = record.data || {};

      if (decision === 'approved') {
        const users = await db.entities.KoraUser.filter({ email: recordData.userEmail });
        if (users && users.length > 0) {
          const u = users[0];
          await db.entities.KoraUser.update(u.id, {
            ...u.data,
            isSuspended: false,
            suspensionReason: '',
            suspensionExpiresAt: '',
            suspensionAppealStatus: 'approved',
          });
        }
        await db.entities.SuspensionRecord.update(suspensionRecordId, {
          ...recordData, status: 'resolved', resolved: true, appealDecision: 'approved',
        });
        return jsonResponse({ success: true, message: 'Appeal approved — account reactivated' });
      } else {
        const users = await db.entities.KoraUser.filter({ email: recordData.userEmail });
        if (users && users.length > 0) {
          const u = users[0];
          await db.entities.KoraUser.update(u.id, { ...u.data, suspensionAppealStatus: 'denied' });
        }
        await db.entities.SuspensionRecord.update(suspensionRecordId, {
          ...recordData, appealDecision: 'denied',
        });
        return jsonResponse({ success: true, message: 'Appeal denied — suspension remains active' });
      }
    }

    return jsonResponse({ error: 'Unknown action. Supported: analyzeMessage, checkSuspensionStatus, submitAppeal, getOwnerSuspensions, resolveAppeal' });
  } catch (error) {
    return jsonResponse({ error: 'Server error: ' + error.message }, 500);
  }
});
