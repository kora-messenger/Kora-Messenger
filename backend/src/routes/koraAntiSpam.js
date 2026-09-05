const express = require('express');
const User = require('../models/User');
const ChatMessage = require('../models/ChatMessage');

const router = express.Router();

// Rate limit thresholds
const MAX_MSGS_PER_MIN_TO_NON_CONTACT = 30;
const MAX_MSGS_PER_MIN_TO_NEW_CONTACT = 5;
const SPAM_SCORE_THRESHOLD = 3; // 3+ reports = auto-flag

// Known spam patterns (regex-based detection)
const SPAM_PATTERNS = [
  /click\s*here\s*to\s*(earn|win|get)/i,
  /free\s*(money|gift|prize|iphone|bitcoin)/i,
  /visit\s*(bit\.ly|tinyurl|t\.me)\//i,
  /whatsapp\s*me\s*at/i,
  /buy\s*(now|cheap|discount)/i,
  /(http|https):\/\/[^\s]+\.(?:tk|ml|ga|cf)/i,
  /you\s*(won|win|have\s*been\s*selected)/i,
  /investment\s*opportunity/i,
  /crypto\s*(giveaway|airdrop)/i,
  /loan\s*approved/i,
  /work\s*from\s*home\s*(earn|make)/i,
];

async function _getSpamScore(email) {
  try {
    const reports = await ChatMessage.find({
      type: 'spam_report',
      actionLabel: email,
    });
    return reports ? reports.length : 0;
  } catch {
    return 0;
  }
}

router.post('/', async (req, res) => {
  const body = req.body || {};
  const { action } = body;

  try {
    // ── REPORT SPAM ────────────────────────────────────
    if (action === 'reportSpam') {
      const { reporterEmail, reportedEmail, chatId, messageId, messageText, reason } = body;
      if (!reporterEmail || !reportedEmail) {
        return res.json({ success: false, error: 'Reporter and reported emails are required' });
      }

      const cleanReporter = String(reporterEmail).toLowerCase().trim();
      const cleanReported = String(reportedEmail).toLowerCase().trim();

      const reportId = 'sr-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8);
      const now = new Date().toISOString();

      await ChatMessage.create({
        userEmail: cleanReporter,
        chatId: chatId || 'spam_reports',
        messageId: reportId,
        text: messageText || '',
        type: 'spam_report',
        isAi: false,
        isMe: false,
        isSeen: false,
        isStarred: false,
        isWebSearch: false,
        timestamp: now,
        lastMessageText: `Spam report: ${reason || 'spam'}`,
        lastMessageTimestamp: now,
        lastMessageType: 'spam_report',
        actionType: 'spam_report',
        actionLabel: cleanReported,
        status: 'sent',
        reaction: '',
        replyToId: messageId || '',
        replyToName: '',
        replyToText: messageText || '',
      });

      const allReports = await ChatMessage.find({
        type: 'spam_report',
        actionLabel: cleanReported,
      });

      const reportCount = allReports ? allReports.length : 0;

      let autoFlagged = false;
      if (reportCount >= SPAM_SCORE_THRESHOLD) {
        const spammer = await User.findOne({ email: cleanReported });
        if (spammer) {
          spammer.suspensionReason = 'spam';
          spammer.suspensionTimestamp = now;
          spammer.suspensionAppealStatus = 'none';
          await spammer.save();
          autoFlagged = true;
        }
      }

      return res.json({
        success: true,
        reportId,
        reportCount,
        autoFlagged,
        message: 'Spam report submitted. Thank you for helping keep Kora safe.',
      });
    }

    // ── CHECK SPAM STATUS ──────────────────────────────
    if (action === 'checkSpam') {
      const { email } = body;
      if (!email) return res.json({ success: false, error: 'Email is required' });

      const lowerEmail = String(email).toLowerCase().trim();

      const user = await User.findOne({ email: lowerEmail });
      if (!user) {
        return res.json({ success: true, isSpammer: false, spamScore: 0 });
      }

      const isSpammer = user.suspensionReason === 'spam' || user.isSuspended === true;
      const spamScore = await _getSpamScore(lowerEmail);

      return res.json({
        success: true,
        isSpammer,
        spamScore,
        spamScoreThreshold: SPAM_SCORE_THRESHOLD,
      });
    }

    // ── RATE LIMIT CHECK ───────────────────────────────
    if (action === 'rateLimit') {
      const { senderEmail, recipientEmail, isFirstMessage } = body;
      if (!senderEmail) return res.json({ success: false, error: 'Sender email is required' });

      const lowerSender = String(senderEmail).toLowerCase().trim();
      const now = Date.now();

      const recentMessages = await ChatMessage.find({
        userEmail: lowerSender,
        isMe: true,
      });

      const msgsLastMin = (recentMessages || []).filter((m) => {
        const msgTime = new Date(m.timestamp || 0).getTime();
        return msgTime > now - 60 * 1000;
      }).length;

      const limit = isFirstMessage ? MAX_MSGS_PER_MIN_TO_NEW_CONTACT : MAX_MSGS_PER_MIN_TO_NON_CONTACT;

      if (msgsLastMin >= limit) {
        return res.json({
          success: true,
          allowed: false,
          retryAfter: 60,
          currentCount: msgsLastMin,
          limit,
          message: "You're sending messages too fast. Please slow down.",
        });
      }

      return res.json({
        success: true,
        allowed: true,
        currentCount: msgsLastMin,
        limit,
      });
    }

    // ── DETECT SPAM CONTENT ────────────────────────────
    if (action === 'detectSpam') {
      const { text, senderEmail } = body;
      if (!text) return res.json({ success: true, isSpam: false, score: 0, matchedPatterns: [] });

      let score = 0;
      const matchedPatterns = [];

      for (const pattern of SPAM_PATTERNS) {
        if (pattern.test(text)) {
          score += 2;
          matchedPatterns.push(pattern.source.substring(0, 40));
        }
      }

      const linkCount = (text.match(/https?:\/\//g) || []).length;
      if (linkCount >= 3) {
        score += 2;
        matchedPatterns.push('excessive_links');
      }

      if (text.length > 20) {
        const upperCount = (text.match(/[A-Z]/g) || []).length;
        const lowerCount = (text.match(/[a-z]/g) || []).length;
        if (lowerCount > 0 && upperCount / (upperCount + lowerCount) > 0.7) {
          score += 1;
          matchedPatterns.push('excessive_caps');
        }
      }

      const words = text.toLowerCase().split(/\s+/);
      if (words.length > 5) {
        const unique = new Set(words);
        if (unique.size / words.length < 0.4) {
          score += 1;
          matchedPatterns.push('repetitive_text');
        }
      }

      if (senderEmail) {
        const senderSpamScore = await _getSpamScore(String(senderEmail).toLowerCase().trim());
        score += Math.min(senderSpamScore, 3);
      }

      return res.json({
        success: true,
        isSpam: score >= 4,
        score,
        matchedPatterns,
      });
    }

    // ── GET SPAM REPORTS (admin) ───────────────────────
    if (action === 'getReports') {
      const { adminEmail, limit, skip } = body;
      if (!adminEmail) return res.json({ success: false, error: 'Admin email is required' });

      const adminUser = await User.findOne({ email: String(adminEmail).toLowerCase().trim() });
      if (!adminUser) {
        return res.json({ success: false, error: 'Not authorized' });
      }
      if (adminUser.role !== 'admin' && adminUser.email !== 'ijeziegoodluck96@gmail.com') {
        return res.json({ success: false, error: 'Not authorized' });
      }

      const maxLimit = Math.min(limit ?? 50, 100);
      const offset = skip ?? 0;

      const reports = await ChatMessage.find({ type: 'spam_report' });

      const sorted = (reports || [])
        .sort((a, b) => {
          const aTime = new Date(a.timestamp || 0).getTime();
          const bTime = new Date(b.timestamp || 0).getTime();
          return bTime - aTime;
        })
        .slice(offset, offset + maxLimit)
        .map((r) => ({
          id: r._id.toString(),
          reportId: r.messageId || '',
          reporterEmail: r.userEmail || '',
          reportedEmail: r.actionLabel || '',
          chatId: r.chatId || '',
          messageId: r.replyToId || '',
          messageText: r.text || '',
          timestamp: r.timestamp || '',
        }));

      return res.json({
        success: true,
        reports: sorted,
        total: reports ? reports.length : 0,
        hasMore: (reports ? reports.length : 0) > offset + maxLimit,
      });
    }

    // ── CLEAR SPAM FLAG (admin) ────────────────────────
    if (action === 'clearFlag') {
      const { adminEmail, targetEmail } = body;
      if (!adminEmail || !targetEmail) {
        return res.json({ success: false, error: 'Admin and target emails are required' });
      }

      const adminUser = await User.findOne({ email: String(adminEmail).toLowerCase().trim() });
      if (!adminUser) {
        return res.json({ success: false, error: 'Not authorized' });
      }
      if (adminUser.role !== 'admin' && adminUser.email !== 'ijeziegoodluck96@gmail.com') {
        return res.json({ success: false, error: 'Not authorized' });
      }

      const target = await User.findOne({ email: String(targetEmail).toLowerCase().trim() });
      if (target) {
        target.suspensionReason = '';
        target.suspensionTimestamp = '';
        target.suspensionAppealStatus = 'cleared';
        await target.save();
      }

      return res.json({ success: true, message: 'Spam flag cleared for ' + targetEmail });
    }

    return res.json({ success: false, error: 'Unknown action: ' + action });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'Internal server error' });
  }
});

module.exports = router;
