const express = require('express');

const router = express.Router();

// Kora Crash Report — 1:1 mirror of the Base44 koraCrashReport function.
// Receives crash logs from the Flutter client and creates GitHub Issues
// in the kora-messenger/Kora-Messenger repo.

const REPO_OWNER = 'kora-messenger';
const REPO_NAME = 'Kora-Messenger';

// In-memory dedup cache (resets on cold start — acceptable for crash dedup)
const recentCrashMessages = new Map();
const DEDUP_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

router.all('/', async (req, res) => {
  try {
    const body = req.body || {};
    const { type, message, stackTrace, appVersion, platform, timestamp } = body;

    // Validate required fields
    if (!type || !message) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Deduplicate: skip if same crash message was seen recently
    const dedupKey = `${type}:${message}`;
    const now = Date.now();
    const lastSeen = recentCrashMessages.get(dedupKey);
    if (lastSeen && now - lastSeen < DEDUP_WINDOW_MS) {
      return res.json({
        success: true,
        deduplicated: true,
        message: 'Crash report skipped (duplicate within 5 min window)',
      });
    }
    recentCrashMessages.set(dedupKey, now);

    // Clean up old dedup entries
    for (const [key, time] of recentCrashMessages) {
      if (now - time > DEDUP_WINDOW_MS) {
        recentCrashMessages.delete(key);
      }
    }

    const githubToken = (
      process.env.GITHUB_TOKEN ||
      process.env.KORA_GITHUB_TOKEN ||
      ''
    ).trim();

    // Build issue title (truncate long messages)
    const shortMsg = message.length > 80 ? message.substring(0, 80) + '…' : message;
    const title = `[Crash][${type}] ${shortMsg}`;

    // Build issue body
    const bodyText = [
      `## Crash Report`,
      ``,
      `**Type:** ${type}`,
      `**Message:** \`${message}\``,
      `**Platform:** ${platform || 'unknown'}`,
      `**App Version:** ${appVersion || 'unknown'}`,
      `**Timestamp:** ${timestamp || new Date().toISOString()}`,
      ``,
      `### Stack Trace`,
      '```',
      stackTrace || '(no stack trace provided)',
      '```',
    ].join('\n');

    // Try to create a GitHub Issue
    if (githubToken.length > 10) {
      try {
        const response = await fetch(
          `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${githubToken}`,
              'Accept': 'application/vnd.github+json',
              'Content-Type': 'application/json',
              'User-Agent': 'Kora-Backend',
            },
            body: JSON.stringify({
              title,
              body: bodyText,
              labels: ['crash', 'auto-reported'],
            }),
          }
        );

        if (response.ok) {
          const issue = await response.json();
          return res.json({
            success: true,
            issueNumber: issue.number,
            issueUrl: issue.html_url,
          });
        } else {
          return res.json({
            success: true,
            stored: true,
            githubError: `GitHub API returned ${response.status}`,
          });
        }
      } catch (githubError) {
        return res.json({
          success: true,
          stored: true,
          githubError: String(githubError),
        });
      }
    }

    // No GitHub token — acknowledge receipt without creating issue
    return res.json({
      success: true,
      stored: true,
      note: 'Crash logged (GITHUB_TOKEN not configured — no issue created)',
    });
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
});

module.exports = router;
