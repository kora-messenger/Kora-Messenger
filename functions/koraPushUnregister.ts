import { base44 } from '@base44/sdk';

/**
 * Unregisters an FCM token for a user.
 * Called on logout or when the token is no longer valid.
 *
 * Body: { email, fcmToken }
 */
export default async function(req: any) {
  const { email, fcmToken } = req.body || {};

  if (!email) {
    return { ok: false, error: 'email is required' };
  }

  try {
    const users = await base44.entities.KoraUser.list({
      filter: { email }
    });

    if (users.length === 0) {
      return { ok: false, error: 'User not found' };
    }

    const user = users[0];

    // Only clear if the token matches (avoid clearing a newer token)
    if (user.fcmToken === fcmToken) {
      await base44.entities.KoraUser.update(user._id, {
        fcmToken: null,
        fcmPlatform: null,
        fcmTokenUpdatedAt: null
      });
    }

    return { ok: true, message: 'FCM token unregistered' };
  } catch (error: any) {
    console.error('[koraPushUnregister] Error:', error.message);
    return { ok: false, error: error.message };
  }
}
