/**
 * Kora — Recover Subscription
 *
 * Re-checks a user's premium status from the database.
 * Used when a user reinstalls the app, switches devices, or had a
 * payment succeed but the local cache wasn't set (crash, etc).
 *
 * Accepts: { userId?, email? } — at least one is required.
 * Returns: { success, isPremium, premiumExpiresAt, premiumSource, user }
 */

import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function computeIsPremium(record: any): boolean {
  const isPremium = record.data?.isPremium ?? record.isPremium ?? false;
  if (!isPremium) return false;
  const source = record.data?.premiumSource ?? record.premiumSource ?? '';
  if (source === 'owner_override') return true;
  const expiresAt = record.data?.premiumExpiresAt ?? record.premiumExpiresAt ?? null;
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() > Date.now();
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
    profileCompleted: record.data?.profileCompleted ?? record.profileCompleted ?? false,
    phoneNumber: record.data?.phoneNumber ?? record.phoneNumber ?? '',
    isPremium: computeIsPremium(record),
    premiumExpiresAt: record.data?.premiumExpiresAt ?? record.premiumExpiresAt ?? null,
    premiumSource: record.data?.premiumSource ?? record.premiumSource ?? '',
  };
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { userId, email } = body;

  try {
    if (!userId && !email) {
      return new Response(
        JSON.stringify({ success: false, error: 'User ID or email is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    let user;
    if (userId) {
      user = await db.entities.KoraUser.get(userId);
    }
    if (!user && email) {
      const users = await db.entities.KoraUser.filter({ email: email.toLowerCase().trim() });
      if (users && users.length > 0) user = users[0];
    }

    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: 'Account not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const isPremium = computeIsPremium(user);
    const premiumExpiresAt = user.data?.premiumExpiresAt ?? user.premiumExpiresAt ?? null;
    const premiumSource = user.data?.premiumSource ?? user.premiumSource ?? '';

    return new Response(
      JSON.stringify({
        success: true,
        isPremium,
        premiumExpiresAt,
        premiumSource,
        user: getUserFromRecord(user),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ success: false, error: e?.message || 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
