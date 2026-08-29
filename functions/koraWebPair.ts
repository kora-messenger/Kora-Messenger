import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Generate a random 32-byte URL-safe base64 token
function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;

  try {
    let body: any = {};
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const { action } = body;

    // ── ACTION: requestPair ──────────────────────────────────────────────
    if (action === 'requestPair') {
      const token = generateToken();
      const nowMs = Date.now();
      const ttlSeconds = 120; // 2 minutes
      const expiresAt = new Date(nowMs + ttlSeconds * 1000).toISOString();

      await db.entities.VerificationCode.create({
        email: '',
        code: token,
        type: 'web_pair',
        used: false,
        expiresAt,
        attempts: 0,
      });

      const qrData = `kora://link?token=${token}&web=true`;

      return jsonResponse({
        success: true,
        pairingToken: token,
        qrData,
        expiresAt,
        ttlSeconds,
      });
    }

    // ── ACTION: pollPair ─────────────────────────────────────────────────
    if (action === 'pollPair') {
      const token = body.token || body.pairingToken;
      if (!token) {
        return jsonResponse({ success: false, error: 'Token is required' }, 400);
      }

      const codes = await db.entities.VerificationCode.filter({
        code: token,
        type: 'web_pair',
      });

      if (!codes || codes.length === 0) {
        return jsonResponse({ success: true, status: 'expired' });
      }

      const vCode = codes[0];
      const used = vCode.data?.used ?? vCode.used ?? false;
      const email = vCode.data?.email ?? vCode.email ?? '';
      const expiresAtStr = vCode.data?.expiresAt ?? vCode.expiresAt;
      const expiresAtDate = new Date(expiresAtStr);
      const isExpired = isNaN(expiresAtDate.getTime()) || expiresAtDate.getTime() < Date.now();

      if (used) {
        if (!email) {
          return jsonResponse({ success: true, status: 'expired' });
        }

        const lowerEmail = email.toLowerCase().trim();
        const users = await db.entities.KoraUser.filter({ email: lowerEmail });

        if (!users || users.length === 0) {
          return jsonResponse({ success: true, status: 'expired' });
        }

        const user = users[0];
        const userData = {
          id: user.id,
          email: user.data?.email ?? user.email ?? lowerEmail,
          username: user.data?.username ?? user.username ?? '',
          koraId: user.data?.koraId ?? user.koraId ?? '',
          fullName: user.data?.fullName ?? user.fullName ?? '',
          bio: user.data?.bio ?? user.bio ?? '',
          avatarUrl: user.data?.avatarUrl ?? user.avatarUrl ?? '',
          isVerified: user.data?.isVerified ?? user.isVerified ?? false,
          profileCompleted: user.data?.profileCompleted ?? user.profileCompleted ?? false,
          phoneNumber: user.data?.phoneNumber ?? user.phoneNumber ?? '',
          isPremium: user.data?.isPremium ?? user.isPremium ?? false,
        };

        return jsonResponse({
          success: true,
          status: 'accepted',
          user: userData,
        });
      }

      if (isExpired) {
        return jsonResponse({ success: true, status: 'expired' });
      }

      return jsonResponse({ success: true, status: 'pending' });
    }

    // ── ACTION: acceptPair ───────────────────────────────────────────────
    if (action === 'acceptPair') {
      const token = body.token || body.pairingToken;
      const email = body.email || body.userEmail || body.ownerEmail;

      if (!token || !email) {
        return jsonResponse({ success: false, error: 'Token and email are required' }, 400);
      }

      const codes = await db.entities.VerificationCode.filter({
        code: token,
        type: 'web_pair',
      });

      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'Invalid pairing code' });
      }

      const vCode = codes[0];
      const used = vCode.data?.used ?? vCode.used ?? false;
      const expiresAtStr = vCode.data?.expiresAt ?? vCode.expiresAt;
      const expiresAtDate = new Date(expiresAtStr);
      const isExpired = isNaN(expiresAtDate.getTime()) || expiresAtDate.getTime() < Date.now();

      if (used || isExpired) {
        return jsonResponse({ success: false, error: 'Pairing code expired or already used' });
      }

      const lowerEmail = email.toLowerCase().trim();
      const users = await db.entities.KoraUser.filter({ email: lowerEmail });

      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      // Mark VerificationCode as used and set email
      await db.entities.VerificationCode.update(vCode.id, {
        used: true,
        email: lowerEmail,
      });

      // Register web device in TrustedDevice
      const now = new Date().toISOString();
      const deviceId = 'web-' + token.substring(0, 8);

      const existingDevices = await db.entities.TrustedDevice.filter({
        userEmail: lowerEmail,
        deviceId,
      });

      if (existingDevices && existingDevices.length > 0) {
        await db.entities.TrustedDevice.update(existingDevices[0].id, {
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
          deviceName: 'Kora Web',
          platform: 'web',
        });
      } else {
        await db.entities.TrustedDevice.create({
          userEmail: lowerEmail,
          deviceId,
          deviceName: 'Kora Web',
          platform: 'web',
          firstLoginDate: now,
          lastLoginDate: now,
          isActive: true,
          isTrusted: true,
        });
      }

      return jsonResponse({
        success: true,
        message: 'Web device linked',
      });
    }

    // ── ACTION: extendToken ──────────────────────────────────────────────
    if (action === 'extendToken') {
      const token = body.token || body.pairingToken;

      if (!token) {
        return jsonResponse({ success: false, error: 'Token is required' }, 400);
      }

      const codes = await db.entities.VerificationCode.filter({
        code: token,
        type: 'web_pair',
      });

      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'Token not found' });
      }

      const vCode = codes[0];
      const used = vCode.data?.used ?? vCode.used ?? false;

      if (used) {
        return jsonResponse({ success: false, error: 'Token already used' });
      }

      const newExpiresAt = new Date(Date.now() + 120 * 1000).toISOString();

      await db.entities.VerificationCode.update(vCode.id, {
        expiresAt: newExpiresAt,
      });

      return jsonResponse({
        success: true,
        expiresAt: newExpiresAt,
      });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action }, 400);
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
