import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Token lifetime: 30 seconds (matching Telegram's QR login refresh cycle).
const TOKEN_TTL_MS = 30 * 1000;

// Generate a random pairing token (URL-safe base64).
function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

// Extract client IP from request headers.
function getClientIp(req: Request): string {
  const headers = req.headers;
  return (
    headers.get('cf-connecting-ip') ||
    headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    headers.get('x-real-ip') ||
    'unknown'
  );
}

// Derive country/region from Cloudflare-style headers.
function getGeo(req: Request): { country: string; region: string } {
  const headers = req.headers;
  return {
    country: headers.get('cf-ipcountry') || headers.get('x-vercel-ip-country') || 'Unknown',
    region: headers.get('cf-region') || headers.get('x-vercel-ip-country-region') || '',
  };
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── GENERATE PAIRING TOKEN (30s auto-refresh) ─────
    if (action === 'generatePairingToken') {
      const { email, appVersion } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();
      const users = await db.entities.KoraUser.filter({ email: lowerEmail });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const token = generateToken();
      const expiresAt = new Date(Date.now() + TOKEN_TTL_MS).toISOString();

      await db.entities.KoraUser.update(users[0].id, {
        securePinHash: token,
      });

      const qrData = 'kora://link?token=' + token + '&email=' + encodeURIComponent(lowerEmail);

      return jsonResponse({
        success: true,
        pairingToken: token,
        expiresAt,
        ttlSeconds: Math.floor(TOKEN_TTL_MS / 1000),
        qrData,
      });
    }

    // ── POLL PAIRING STATUS (Confirmation step) ──────
    if (action === 'pollPairingStatus') {
      const { pairingToken, email } = body;
      if (!pairingToken || !email) return jsonResponse({ success: false, error: 'Missing parameters' });

      const lowerEmail = email.toLowerCase().trim();
      const users = await db.entities.KoraUser.filter({ email: lowerEmail });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const storedToken = users[0].data?.securePinHash ?? users[0].securePinHash ?? '';

      if (!storedToken) {
        return jsonResponse({ success: true, status: 'accepted' });
      }
      if (storedToken !== pairingToken) {
        return jsonResponse({ success: true, status: 'expired' });
      }
      return jsonResponse({ success: true, status: 'pending' });
    }

    // ── LINK DEVICE (Accept step) ────────────────────
    if (action === 'linkDevice') {
      const {
        pairingToken, ownerEmail, newDeviceId, newDeviceName, newPlatform, appVersion,
      } = body;

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

      if (!storedToken) {
        return jsonResponse({ success: false, error: 'No active pairing code. Generate a new one.' });
      }
      if (storedToken !== pairingToken) {
        return jsonResponse({ success: false, error: 'Invalid or expired pairing code. The code may have refreshed.' });
      }

      const clientIp = getClientIp(req);
      const geo = getGeo(req);
      const now = new Date().toISOString();

      const existing = await db.entities.TrustedDevice.filter({
        userEmail: lowerEmail,
        deviceId: newDeviceId,
      });

      if (existing && existing.length > 0) {
        await db.entities.TrustedDevice.update(existing[0].id, {
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
          deviceName: newDeviceName ?? existing[0].data?.deviceName,
          platform: newPlatform ?? existing[0].data?.platform,
        });
      } else {
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

      await db.entities.KoraUser.update(user.id, {
        securePinHash: '',
      });

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
        isPremium: user.data?.isPremium ?? user.isPremium ?? false,
        premiumExpiresAt: user.data?.premiumExpiresAt ?? user.premiumExpiresAt ?? null,
      };

      return jsonResponse({
        success: true,
        user: userData,
        deviceId: newDeviceId,
        deviceName: newDeviceName,
        sessionInfo: {
          ip: clientIp,
          country: geo.country,
          region: geo.region,
          appVersion: appVersion || 'unknown',
          linkedAt: now,
        },
        message: 'Device linked successfully',
      });
    }

    // ── LIST DEVICES ─────────────────────────────────
    if (action === 'listDevices') {
      const { email } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const lowerEmail = email.toLowerCase().trim();
      const devices = await db.entities.TrustedDevice.filter({ userEmail: lowerEmail });

      return jsonResponse({
        success: true,
        devices: (devices || []).map((d: any) => ({
          id: d.id,
          deviceId: d.data?.deviceId ?? d.deviceId ?? '',
          deviceName: d.data?.deviceName ?? d.deviceName ?? 'Unknown Device',
          platform: d.data?.platform ?? d.platform ?? 'unknown',
          firstLoginDate: d.data?.firstLoginDate ?? d.firstLoginDate ?? null,
          lastLoginDate: d.data?.lastLoginDate ?? d.lastLoginDate ?? null,
          isActive: d.data?.isActive ?? d.isActive ?? true,
          isTrusted: d.data?.isTrusted ?? d.isTrusted ?? false,
        })),
      });
    }

    // ── LOGOUT DEVICE ─────────────────────────────────
    if (action === 'logoutDevice') {
      const { email, deviceRecordId } = body;
      if (!email || !deviceRecordId) return jsonResponse({ success: false, error: 'Missing parameters' });

      const lowerEmail = email.toLowerCase().trim();
      const device = await db.entities.TrustedDevice.filter({
        userEmail: lowerEmail,
        id: deviceRecordId,
      });

      if (!device || device.length === 0) {
        return jsonResponse({ success: false, error: 'Device not found' });
      }

      await db.entities.TrustedDevice.delete(device[0].id);
      return jsonResponse({ success: true, message: 'Session terminated' });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
