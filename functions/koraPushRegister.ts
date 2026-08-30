import { base44, route, http } from '@base44/sdk';

/**
 * Registers an FCM token for a user.
 * Called by the Flutter app when it acquires a new Firebase Cloud Messaging token.
 *
 * Body: { email, fcmToken, platform, timestamp }
 */
export default async function(req: any) {
  const { email, fcmToken, platform, timestamp } = req.body || {};

  if (!email || !fcmToken) {
    return { ok: false, error: 'email and fcmToken are required' };
  }

  try {
    // Find the user by email
    const users = await base44.entities.KoraUser.list({
      filter: { email }
    });

    if (users.length === 0) {
      return { ok: false, error: 'User not found' };
    }

    const user = users[0];

    // Update the user's FCM token
    await base44.entities.KoraUser.update(user._id, {
      fcmToken,
      fcmPlatform: platform || 'android',
      fcmTokenUpdatedAt: new Date().toISOString()
    });

    return { ok: true, message: 'FCM token registered' };
  } catch (error: any) {
    console.error('[koraPushRegister] Error:', error.message);
    return { ok: false, error: error.message };
  }
}
