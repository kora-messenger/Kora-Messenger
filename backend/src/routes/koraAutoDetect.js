const express = require('express');
const User = require('../models/User');
const SuspensionRecord = require('../models/SuspensionRecord');

const router = express.Router();

const OWNER_EMAIL = 'ijeziegoodluck@gmail.com';

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

function analyzeContent(content, recipientCount) {
  const lower = (content || '').toLowerCase().trim();
  const flags = [];
  let severity = 0;
  let detectionType = 'other';
  let detectionDetails = '';

  for (const p of CHILD_SAFETY_PATTERNS) {
    if (p.test(lower)) {
      flags.push('child_safety_violation');
      severity = 10;
      detectionType = 'child_safety';
      detectionDetails = 'CHILD SAFETY VIOLATION: Immediate suspension triggered';
    }
  }

  for (const p of PHISHING_PATTERNS) {
    if (p.test(lower)) {
      flags.push('phishing_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'phishing'; detectionDetails = 'Phishing/credential theft attempt detected'; }
    }
  }

  for (const p of MALWARE_PATTERNS) {
    if (p.test(lower)) {
      flags.push('malware_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'malware'; detectionDetails = 'Potential malware/malicious file sharing detected'; }
    }
  }

  for (const p of IMPERSONATION_PATTERNS) {
    if (p.test(lower)) {
      flags.push('impersonation_pattern');
      severity = Math.max(severity, 5);
      if (detectionType === 'other') { detectionType = 'impersonation'; detectionDetails = 'Impersonation of Kora official account detected'; }
    }
  }

  for (const p of HATE_SPEECH_PATTERNS) {
    if (p.test(lower)) {
      flags.push('hate_speech');
      severity = Math.max(severity, 6);
      if (detectionType === 'other') { detectionType = 'hate_speech'; detectionDetails = 'Hate speech / targeted abuse detected'; }
    }
  }

  for (const p of ILLEGAL_PATTERNS) {
    if (p.test(lower)) {
      flags.push('illegal_activity');
      severity = Math.max(severity, 6);
      if (detectionType === 'other') { detectionType = 'illegal_activity'; detectionDetails = 'Illegal activity detected in message content'; }
    }
  }

  for (const p of HARASSMENT_PATTERNS) {
    if (p.test(lower)) {
      flags.push('harassment_pattern');
      severity = Math.max(severity, 4);
      if (detectionType === 'other') { detectionType = 'harassment'; detectionDetails = 'Harassment/threatening content detected'; }
    }
  }

  for (const p of FRAUD_PATTERNS) {
    if (p.test(lower)) {
      flags.push('fraud_pattern');
      severity = Math.max(severity, 4);
      if (detectionType === 'other') { detectionType = 'fraud'; detectionDetails = 'Fraudulent/scam content detected in message'; }
    }
  }

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

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action } = body;

  try {
    // ── ANALYZE MESSAGE ──────────────────────────────────
    if (action === 'analyzeMessage') {
      const { userEmail, userKoraId, username, messageContent, recipientCount } = body;
      if (!userEmail || !messageContent) {
        return res.json({ suspended: false, flags: [] });
      }

      const cleanEmail = String(userEmail).toLowerCase().trim();
      const result = analyzeContent(messageContent, recipientCount);

      if (result.severity >= 3 && result.flags.length > 0) {
        const user = await User.findOne({ email: cleanEmail });
        if (!user) {
          return res.json({ suspended: false, flags: result.flags, severity: result.severity, error: 'User not found' });
        }

        if (user.isSuspended) {
          return res.json({ suspended: true, alreadySuspended: true, flags: result.flags, message: 'User is already suspended' });
        }

        const now = new Date();
        let suspensionHours = 24;
        let isPermanent = false;

        if (result.severity >= 10) isPermanent = true;
        else if (result.severity >= 7) suspensionHours = 720;
        else if (result.severity >= 5) suspensionHours = 168;

        const expiresAt = isPermanent ? 'permanent' : new Date(now.getTime() + suspensionHours * 3600000).toISOString();

        user.isSuspended = true;
        user.suspensionReason = result.detectionDetails;
        user.suspensionTimestamp = now.toISOString();
        user.suspensionExpiresAt = expiresAt;
        user.suspensionAppealStatus = 'none';
        await user.save();

        await SuspensionRecord.create({
          userEmail: cleanEmail,
          userKoraId: userKoraId || user.koraId || '',
          username: username || user.username || '',
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

        return res.json({
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

      return res.json({
        suspended: false,
        flags: result.flags,
        severity: result.severity,
        message: result.flags.length === 0 ? 'No violations detected' : 'Minor flags — no suspension',
      });
    }

    // ── CHECK SUSPENSION STATUS ──────────────────────────
    if (action === 'checkSuspensionStatus') {
      const { email } = body;
      if (!email) return res.json({ suspended: false });

      const cleanEmail = String(email).toLowerCase().trim();
      const user = await User.findOne({ email: cleanEmail });
      if (!user) return res.json({ suspended: false });

      if (!user.isSuspended) return res.json({ suspended: false });

      if (user.suspensionExpiresAt && user.suspensionExpiresAt !== 'permanent') {
        const expiresAt = new Date(user.suspensionExpiresAt);
        const now = new Date();
        if (now > expiresAt) {
          user.isSuspended = false;
          user.suspensionReason = '';
          user.suspensionExpiresAt = '';
          user.suspensionAppealStatus = 'none';
          await user.save();

          await SuspensionRecord.updateMany(
            { userEmail: cleanEmail, status: 'active' },
            { $set: { status: 'expired', resolved: true } }
          );

          return res.json({ suspended: false, wasSuspended: true });
        }

        const hoursRemaining = Math.ceil((expiresAt.getTime() - now.getTime()) / 3600000);
        return res.json({
          suspended: true,
          reason: user.suspensionReason || 'Your account has been suspended for violating Kora Messenger Community Guidelines.',
          expiresAt: user.suspensionExpiresAt,
          hoursRemaining,
          isPermanent: false,
          appealStatus: user.suspensionAppealStatus || 'none',
        });
      }

      return res.json({
        suspended: true,
        reason: user.suspensionReason || 'Your account has been permanently suspended for severe violations of Kora Messenger Community Guidelines.',
        expiresAt: 'permanent',
        isPermanent: true,
        appealStatus: user.suspensionAppealStatus || 'none',
      });
    }

    // ── SUBMIT APPEAL ─────────────────────────────────────
    if (action === 'submitAppeal') {
      const { email, appealMessage } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const cleanEmail = String(email).toLowerCase().trim();
      const user = await User.findOne({ email: cleanEmail });
      if (!user) return res.json({ success: false, error: 'User not found' });

      if (!user.isSuspended) return res.json({ success: false, error: 'Account is not suspended' });

      if (user.suspensionAppealStatus === 'pending') {
        return res.json({ success: false, error: 'You have already submitted an appeal. Please wait for a response.' });
      }

      if (user.suspensionAppealStatus === 'denied') {
        return res.json({ success: false, error: 'Your appeal has been denied. You must wait for your suspension to expire.' });
      }

      const now = new Date().toISOString();

      user.suspensionAppealStatus = 'pending';
      await user.save();

      await SuspensionRecord.updateMany(
        { userEmail: cleanEmail, status: 'active' },
        { $set: { status: 'appealed', appealMessage: appealMessage || '', appealSubmittedAt: now } }
      );

      return res.json({
        success: true,
        message: 'Your appeal has been submitted. Please allow up to 24 hours for a response.',
      });
    }

    // ── GET OWNER SUSPENSIONS ─────────────────────────────
    if (action === 'getOwnerSuspensions') {
      const { ownerEmail } = body;
      if (ownerEmail !== OWNER_EMAIL) {
        return res.json({ authorized: false, message: 'Only the Kora owner can view suspensions' });
      }

      const records = await SuspensionRecord.find({ resolved: false });
      return res.json({
        authorized: true,
        suspensions: (records || []).map((r) => ({
          id: r._id.toString(),
          userEmail: r.userEmail,
          userKoraId: r.userKoraId,
          username: r.username,
          detectionType: r.detectionType,
          detectionDetails: r.detectionDetails,
          reason: r.reason,
          suspendedAt: r.suspendedAt,
          expiresAt: r.expiresAt,
          status: r.status,
          autoDetected: r.autoDetected,
          suspendedBy: r.suspendedBy,
          ownerNotified: r.ownerNotified,
          resolved: r.resolved,
          appealDecision: r.appealDecision,
          appealMessage: r.appealMessage,
          appealSubmittedAt: r.appealSubmittedAt,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        })),
        count: (records || []).length,
      });
    }

    // ── RESOLVE APPEAL ────────────────────────────────────
    if (action === 'resolveAppeal') {
      const { ownerEmail, suspensionRecordId, decision } = body;
      if (ownerEmail !== OWNER_EMAIL) {
        return res.json({ authorized: false, message: 'Only the Kora owner can resolve appeals' });
      }

      if (!['approved', 'denied'].includes(decision)) {
        return res.json({ error: 'Invalid decision' });
      }

      const record = await SuspensionRecord.findById(suspensionRecordId);
      if (!record) {
        return res.json({ error: 'Suspension record not found' });
      }

      if (decision === 'approved') {
        const targetUser = await User.findOne({ email: record.userEmail });
        if (targetUser) {
          targetUser.isSuspended = false;
          targetUser.suspensionReason = '';
          targetUser.suspensionExpiresAt = '';
          targetUser.suspensionAppealStatus = 'approved';
          await targetUser.save();
        }
        record.status = 'resolved';
        record.resolved = true;
        record.appealDecision = 'approved';
        await record.save();

        return res.json({ success: true, message: 'Appeal approved — account reactivated' });
      } else {
        const targetUser = await User.findOne({ email: record.userEmail });
        if (targetUser) {
          targetUser.suspensionAppealStatus = 'denied';
          await targetUser.save();
        }
        record.appealDecision = 'denied';
        await record.save();

        return res.json({ success: true, message: 'Appeal denied — suspension remains active' });
      }
    }

    return res.json({ error: 'Unknown action. Supported: analyzeMessage, checkSuspensionStatus, submitAppeal, getOwnerSuspensions, resolveAppeal' });
  } catch (error) {
    return res.status(500).json({ error: 'Server error: ' + error.message });
  }
});

module.exports = router;
