import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Rate limit thresholds
const MAX_MSGS_PER_MIN_TO_NON_CONTACT = 30;
const MAX_MSGS_PER_MIN_TO_NEW_CONTACT = 5;
const NEW_CONTACT_WINDOW_MS = 24 * 60 * 60 * 1000; // 24 hours
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

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── REPORT SPAM ────────────────────────────────────
    // A user reports another user/chat as spam. Stores the report
    // and auto-flags the sender if they accumulate enough reports.
    if (action === 'reportSpam') {
      const { reporterEmail, reportedEmail, chatId, messageId, messageText, reason } = body;
      if (!reporterEmail || !reportedEmail) {
        return jsonResponse({ success: false, error: 'Reporter and reported emails are required' });
      }

      const reportId = 'sr-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8);
      const now = new Date().toISOString();

      // Store the report as a ChatMessage with type 'spam_report'
      await db.entities.ChatMessage.create({
        userEmail: reporterEmail.toLowerCase().trim(),
        chatId: chatId ?? 'spam_reports',
        messageId: reportId,
        text: messageText ?? '',
        type: 'spam_report',
        isAi: false,
        isMe: false,
        isSeen: false,
        isStarred: false,
        isWebSearch: false,
        timestamp: now,
        lastMessageText: `Spam report: ${reason ?? 'spam'}`,
        lastMessageTimestamp: now,
        lastMessageType: 'spam_report',
        actionType: 'spam_report',
        actionLabel: reportedEmail.toLowerCase().trim(),
        status: 'sent',
        reaction: '',
        replyToId: messageId ?? '',
        replyToName: '',
        replyToText: messageText ?? '',
      });

      // Count total reports against this user
      const allReports = await db.entities.ChatMessage.filter({
        type: 'spam_report',
        actionLabel: reportedEmail.toLowerCase().trim(),
      });

      const reportCount = allReports?.length ?? 0;

      // Auto-flag the user if they've been reported enough times
      let autoFlagged = false;
      if (reportCount >= SPAM_SCORE_THRESHOLD) {
        // Update the reported user's KoraUser record to mark them as a spammer
        const spammer = await db.entities.KoraUser.filter({
          email: reportedEmail.toLowerCase().trim(),
        });
        if (spammer && spammer.length > 0) {
          await db.entities.KoraUser.update(spammer[0].id, {
            suspensionReason: 'spam',
            suspensionTimestamp: now,
            suspensionAppealStatus: 'none',
          });
          autoFlagged = true;
        }
      }

      return jsonResponse({
        success: true,
        reportId,
        reportCount,
        autoFlagged,
        message: 'Spam report submitted. Thank you for helping keep Kora safe.',
      });
    }

    // ── CHECK SPAM STATUS ──────────────────────────────
    // Check if a user is flagged as a spammer (used before opening a chat)
    if (action === 'checkSpam') {
      const { email } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();

      const user = await db.entities.KoraUser.filter({ email: lowerEmail });
      if (!user || user.length === 0) {
        return jsonResponse({ success: true, isSpammer: false, spamScore: 0 });
      }

      const userData = user[0].data ?? user[0];
      const isSpammer = userData?.suspensionReason === 'spam' || userData?.isSuspended === true;
      const spamScore = await _getSpamScore(db, lowerEmail);

      return jsonResponse({
        success: true,
        isSpammer,
        spamScore,
        spamScoreThreshold: SPAM_SCORE_THRESHOLD,
      });
    }

    // ── RATE LIMIT CHECK ───────────────────────────────
    // Checks if a sender is exceeding message rate limits.
    // Returns { allowed: boolean, retryAfter: number }
    if (action === 'rateLimit') {
      const { senderEmail, recipientEmail, isFirstMessage } = body;
      if (!senderEmail) return jsonResponse({ success: false, error: 'Sender email is required' });

      const lowerSender = senderEmail.toLowerCase().trim();
      const now = Date.now();
      const oneMinAgo = new Date(now - 60 * 1000).toISOString();

      // Count messages sent in the last minute
      const recentMessages = await db.entities.ChatMessage.filter({
        userEmail: lowerSender,
        isMe: true,
      });

      const msgsLastMin = (recentMessages || []).filter((m: any) => {
        const msgTime = new Date(m.data?.timestamp ?? m.timestamp ?? 0).getTime();
        return msgTime > now - 60 * 1000;
      }).length;

      // Determine the limit based on whether this is a first message to a new contact
      const limit = isFirstMessage ? MAX_MSGS_PER_MIN_TO_NEW_CONTACT : MAX_MSGS_PER_MIN_TO_NON_CONTACT;

      if (msgsLastMin >= limit) {
        return jsonResponse({
          success: true,
          allowed: false,
          retryAfter: 60,
          currentCount: msgsLastMin,
          limit,
          message: 'You\'re sending messages too fast. Please slow down.',
        });
      }

      return jsonResponse({
        success: true,
        allowed: true,
        currentCount: msgsLastMin,
        limit,
      });
    }

    // ── DETECT SPAM CONTENT ────────────────────────────
    // Heuristic-based spam detection for a message text.
    // Returns { isSpam: boolean, score: number, matchedPatterns: string[] }
    if (action === 'detectSpam') {
      const { text, senderEmail } = body;
      if (!text) return jsonResponse({ success: true, isSpam: false, score: 0, matchedPatterns: [] });

      let score = 0;
      const matchedPatterns: string[] = [];

      // Check against known spam patterns
      for (const pattern of SPAM_PATTERNS) {
        if (pattern.test(text)) {
          score += 2;
          matchedPatterns.push(pattern.source.substring(0, 40));
        }
      }

      // Check for excessive links
      const linkCount = (text.match(/https?:\/\//g) || []).length;
      if (linkCount >= 3) {
        score += 2;
        matchedPatterns.push('excessive_links');
      }

      // Check for excessive capitalization
      if (text.length > 20) {
        const upperCount = (text.match(/[A-Z]/g) || []).length;
        const lowerCount = (text.match(/[a-z]/g) || []).length;
        if (lowerCount > 0 && upperCount / (upperCount + lowerCount) > 0.7) {
          score += 1;
          matchedPatterns.push('excessive_caps');
        }
      }

      // Check for repetitive text
      const words = text.toLowerCase().split(/\s+/);
      if (words.length > 5) {
        const unique = new Set(words);
        if (unique.size / words.length < 0.4) {
          score += 1;
          matchedPatterns.push('repetitive_text');
        }
      }

      // Check sender's spam score from reports
      if (senderEmail) {
        const senderSpamScore = await _getSpamScore(db, senderEmail.toLowerCase().trim());
        score += Math.min(senderSpamScore, 3);
      }

      return jsonResponse({
        success: true,
        isSpam: score >= 4,
        score,
        matchedPatterns,
      });
    }

    // ── GET SPAM REPORTS (admin) ───────────────────────
    if (action === 'getReports') {
      const { adminEmail, limit, skip } = body;
      if (!adminEmail) return jsonResponse({ success: false, error: 'Admin email is required' });

      // Verify the requester is an admin (check KoraUser role)
      const adminUser = await db.entities.KoraUser.filter({ email: adminEmail.toLowerCase().trim() });
      if (!adminUser || adminUser.length === 0) {
        return jsonResponse({ success: false, error: 'Not authorized' });
      }
      const adminData = adminUser[0].data ?? adminUser[0];
      if (adminData?.role !== 'admin' && adminData?.email !== 'ijeziegoodluck96@gmail.com') {
        return jsonResponse({ success: false, error: 'Not authorized' });
      }

      const maxLimit = Math.min(limit ?? 50, 100);
      const offset = skip ?? 0;

      const reports = await db.entities.ChatMessage.filter({ type: 'spam_report' });

      const sorted = (reports || [])
        .sort((a: any, b: any) => {
          const aTime = new Date(a.data?.timestamp ?? a.timestamp ?? 0).getTime();
          const bTime = new Date(b.data?.timestamp ?? b.timestamp ?? 0).getTime();
          return bTime - aTime;
        })
        .slice(offset, offset + maxLimit)
        .map((r: any) => ({
          id: r.id,
          reportId: r.data?.messageId ?? r.messageId ?? '',
          reporterEmail: r.data?.userEmail ?? r.userEmail ?? '',
          reportedEmail: r.data?.actionLabel ?? r.actionLabel ?? '',
          chatId: r.data?.chatId ?? r.chatId ?? '',
          messageId: r.data?.replyToId ?? r.replyToId ?? '',
          messageText: r.data?.text ?? r.text ?? '',
          timestamp: r.data?.timestamp ?? r.timestamp ?? '',
        }));

      return jsonResponse({
        success: true,
        reports: sorted,
        total: reports?.length ?? 0,
        hasMore: (reports?.length ?? 0) > offset + maxLimit,
      });
    }

    // ── CLEAR SPAM FLAG (admin) ────────────────────────
    if (action === 'clearFlag') {
      const { adminEmail, targetEmail } = body;
      if (!adminEmail || !targetEmail) {
        return jsonResponse({ success: false, error: 'Admin and target emails are required' });
      }

      // Verify admin
      const adminUser = await db.entities.KoraUser.filter({ email: adminEmail.toLowerCase().trim() });
      if (!adminUser || adminUser.length === 0) {
        return jsonResponse({ success: false, error: 'Not authorized' });
      }
      const adminData = adminUser[0].data ?? adminUser[0];
      if (adminData?.role !== 'admin' && adminData?.email !== 'ijeziegoodluck96@gmail.com') {
        return jsonResponse({ success: false, error: 'Not authorized' });
      }

      const target = await db.entities.KoraUser.filter({ email: targetEmail.toLowerCase().trim() });
      if (target && target.length > 0) {
        await db.entities.KoraUser.update(target[0].id, {
          suspensionReason: '',
          suspensionTimestamp: '',
          suspensionAppealStatus: 'cleared',
        });
      }

      return jsonResponse({ success: true, message: 'Spam flag cleared for ' + targetEmail });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});

// Helper: get spam score (number of reports) for a user
async function _getSpamScore(db: any, email: string): Promise<number> {
  try {
    const reports = await db.entities.ChatMessage.filter({
      type: 'spam_report',
      actionLabel: email,
    });
    return reports?.length ?? 0;
  } catch {
    return 0;
  }
}
