import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── GENERATE PAIRING TOKEN ────────────────────────────────
    // Generates a single-use, 5-minute expiry pairing token.
    // Encoded as a QR code for device linking.
    if (action === 'generatePairingToken') {
      const { email } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();
      const users = await db.entities.KoraUser.filter({ email: lowerEmail });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      // Generate a random pairing token
      const token = 'KP-' + Date.now().toString(36).toUpperCase() +
        Math.random().toString(36).substring(2, 10).toUpperCase();
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString(); // 5 min

      // Store token in the user's securePinHash field (single-use)
      await db.entities.KoraUser.update(users[0].id, {
        securePinHash: token,
      });

      return jsonResponse({
        success: true,
        pairingToken: token,
        expiresAt,
        qrData: 'kora://link?token=' + token + '&email=' + encodeURIComponent(lowerEmail),
      });
    }

    // ── LINK DEVICE ────────────────────────────────────────────
    // Validates a pairing token and registers a new device session.
    // Called by the device that scanned the QR code.
    if (action === 'linkDevice') {
      const { pairingToken, ownerEmail, newDeviceId, newDeviceName, newPlatform } = body;
      if (!pairingToken) return jsonResponse({ success: false, error: 'Pairing token is required' });
      if (!ownerEmail) return jsonResponse({ success: false, error: 'Owner email is required' });
      if (!newDeviceId) return jsonResponse({ success: false, error: 'Device ID is required' });

      const lowerEmail = ownerEmail.toLowerCase().trim();
      const users = await db.entities.KoraUser.filter({ email: lowerEmail });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const user = users[0];
      const storedToken = user.data?.securePinHash ?? user.securePinHash ?? '';

      // Validate the pairing token
      if (!storedToken || storedToken !== pairingToken) {
        return jsonResponse({ success: false, error: 'Invalid or expired pairing code' });
      }

      // Check if this device is already registered
      const existing = await db.entities.TrustedDevice.filter({
        userEmail: lowerEmail,
        deviceId: newDeviceId,
      });

      const now = new Date().toISOString();

      if (existing && existing.length > 0) {
        // Update existing device record
        await db.entities.TrustedDevice.update(existing[0].id, {
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
          deviceName: newDeviceName ?? existing[0].data?.deviceName,
          platform: newPlatform ?? existing[0].data?.platform,
        });
      } else {
        // Create new trusted device record
        await db.entities.TrustedDevice.create({
          userEmail: lowerEmail,
          deviceId: newDeviceId,
          deviceName: newDeviceName || 'Unknown Device',
          platform: newPlatform || 'unknown',
          firstLoginDate: now,
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
        });
      }

      // Clear the pairing token (single-use)
      await db.entities.KoraUser.update(user.id, {
        securePinHash: '',
      });

      // Return the user's session data so the linking device can log in
      const userData = {
        id: user.id,
        email: user.data?.email ?? user.email ?? '',
        username: user.data?.username ?? user.username ?? '',
        koraId: user.data?.koraId ?? user.koraId ?? '',
        fullName: user.data?.fullName ?? user.fullName ?? '',
        bio: user.data?.bio ?? user.bio ?? '',
        avatarUrl: user.data?.avatarUrl ?? user.avatarUrl ?? '',
        isVerified: user.data?.isVerified ?? user.isVerified ?? true,
        profileCompleted: user.data?.profileCompleted ?? user.profileCompleted ?? false,
        phoneNumber: user.data?.phoneNumber ?? user.phoneNumber ?? '',
      };

      return jsonResponse({
        success: true,
        user: userData,
        deviceId: newDeviceId,
        deviceName: newDeviceName,
        message: 'Device linked successfully',
      });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });

  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
