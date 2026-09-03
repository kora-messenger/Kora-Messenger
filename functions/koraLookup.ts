import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function getUserFromRecord(record: any) {
  return {
    id: record.id,
    email: record.data?.email ?? record.email ?? '',
    username: record.data?.username ?? record.username ?? '',
    koraId: record.data?.koraId ?? record.koraId ?? '',
    fullName: record.data?.fullName ?? record.fullName ?? '',
    bio: record.data?.bio ?? record.bio ?? '',
    avatarUrl: record.data?.avatarUrl ?? record.avatarUrl ?? '',
    isVerified: record.data?.isVerified ?? record.isVerified ?? true,
    // Required by the client to show the premium badge next to the
    // user's name when opening a chat with them. Without this field the
    // client always sees a non-premium user and never shows the badge.
    isPremium: (record.data?.isPremium ?? record.isPremium ?? false) === true,
    isSuspended: (record.data?.isSuspended ?? record.isSuspended ?? false) === true,
    profileCompleted: record.data?.profileCompleted ?? record.profileCompleted ?? false,
    phoneNumber: record.data?.phoneNumber ?? record.phoneNumber ?? '',
  };
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── LOOKUP USER (by username or koraId) ────────────────────
    if (action === 'lookupUser') {
      const { identifier } = body;
      if (!identifier) return jsonResponse({ success: false, error: 'Identifier is required' });

      const trimmed = identifier.trim();
      // Check if it looks like a Kora ID (starts with KM-)
      if (trimmed.toUpperCase().startsWith('KM-')) {
        const users = await db.entities.KoraUser.filter({ koraId: trimmed.toUpperCase() });
        if (users && users.length > 0) {
          return jsonResponse({
            success: true,
            found: true,
            type: 'koraId',
            user: getUserFromRecord(users[0]),
          });
        }
        return jsonResponse({ success: true, found: false, type: 'koraId' });
      }

      // Otherwise treat as username (strip leading @)
      let username = trimmed;
      if (username.startsWith('@')) username = username.substring(1);
      const lower = username.toLowerCase();
      const users = await db.entities.KoraUser.filter({ username: lower });
      if (users && users.length > 0) {
        return jsonResponse({
          success: true,
          found: true,
          type: 'username',
          user: getUserFromRecord(users[0]),
        });
      }
      return jsonResponse({ success: true, found: false, type: 'username' });
    }

    return jsonResponse({ success: false, error: `Unknown action: ${action}` });
  } catch (error: any) {
    console.error('koraLookup error:', error);
    return jsonResponse({ success: false, error: error.message || 'Internal server error' }, 500);
  }
});
