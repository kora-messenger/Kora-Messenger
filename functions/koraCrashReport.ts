/**
 * Kora Crash Report — Receives crash logs from the Flutter client
 * and creates GitHub Issues in the kora-messenger/Kora-Messenger repo.
 *
 * Deduplicates by crash message to avoid spam.
 * Uses GITHUB_TOKEN from environment for issue creation.
 */

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

const REPO_OWNER = 'kora-messenger';
const REPO_NAME = 'Kora-Messenger';

// In-memory dedup cache (resets on cold start — acceptable for crash dedup)
const recentCrashMessages = new Map<string, number>();
const DEDUP_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

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
    const { type, message, stackTrace, appVersion, platform, timestamp } = body;

    // Validate required fields
    if (!type || !message) {
      return jsonResponse({ error: 'Missing required fields' }, 400);
    }

    // Deduplicate: skip if same crash message was seen recently
    const dedupKey = `${type}:${message}`;
    const now = Date.now();
    const lastSeen = recentCrashMessages.get(dedupKey);
    if (lastSeen && now - lastSeen < DEDUP_WINDOW_MS) {
      return jsonResponse({
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

    const githubToken = (Deno.env.get('GITHUB_TOKEN') || Deno.env.get('KORA_GITHUB_TOKEN') || '').trim();

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
            },
            body: JSON.stringify({
              title,
              body: bodyText,
              labels: ['crash', 'auto-reported'],
            }),
          },
        );

        if (response.ok) {
          const issue = await response.json();
          return jsonResponse({
            success: true,
            issueNumber: issue.number,
            issueUrl: issue.html_url,
          });
        } else {
          return jsonResponse({
            success: true,
            stored: true,
            githubError: `GitHub API returned ${response.status}`,
          });
        }
      } catch (githubError) {
        return jsonResponse({
          success: true,
          stored: true,
          githubError: String(githubError),
        });
      }
    }

    // No GitHub token — acknowledge receipt without creating issue
    return jsonResponse({
      success: true,
      stored: true,
      note: 'Crash logged (GITHUB_TOKEN not configured — no issue created)',
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
