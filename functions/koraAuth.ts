import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';
import nodemailer from 'npm:nodemailer@6.9.14';
import crypto from 'node:crypto';

// ─────────────────────────────────────────────────────────────
//  Domain-swappable config — change these when you get a .com
// ─────────────────────────────────────────────────────────────
const SMTP_HOST = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com';
const SMTP_PORT = parseInt(Deno.env.get('SMTP_PORT') || '587');
const SMTP_USER = Deno.env.get('SMTP_USER') || 'koramessengerofficial@gmail.com';
const SMTP_PASS = Deno.env.get('SMTP_PASS') || '';
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') || 'Kora Messenger <koramessengerofficial@gmail.com>';
const APP_NAME = 'Kora Messenger';

function generateCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

let transporter: any = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: SMTP_PORT === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });
  }
  return transporter;
}

function premiumEmailTemplate(title: string, bodyHtml: string, codeBlock = ''): string {
  const year = new Date().getFullYear();
  return `
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#050508;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#050508;min-height:100vh;">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table width="480" cellpadding="0" cellspacing="0" style="background:linear-gradient(180deg,#0A0A14 0%,#13131F 100%);border-radius:24px;overflow:hidden;box-shadow:0 8px 40px rgba(99,102,241,0.15);">

          <!-- Header bar -->
          <tr>
            <td style="background:linear-gradient(135deg,#8B5CF6 0%,#3B82F6 100%);padding:32px 40px;text-align:center;">
              <div style="width:56px;height:56px;background:rgba(255,255,255,0.15);border-radius:16px;line-height:56px;color:white;font-size:32px;font-weight:800;margin:0 auto;">K</div>
              <h1 style="margin:16px 0 0;color:#FFFFFF;font-size:22px;font-weight:800;letter-spacing:-0.5px;">${APP_NAME}</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px 20px;">
              <h2 style="margin:0 0 16px;color:#FFFFFF;font-size:18px;font-weight:700;">${title}</h2>
              <div style="color:#A0A0B8;font-size:15px;line-height:1.6;">
                ${bodyHtml}
              </div>
              ${codeBlock ? `
              <div style="text-align:center;margin:28px 0;">
                <div style="display:inline-block;padding:22px 44px;background:linear-gradient(135deg,#8B5CF6 0%,#3B82F6 100%);border-radius:18px;box-shadow:0 6px 24px rgba(99,102,241,0.35);">
                  <span style="color:#FFFFFF;font-size:36px;font-weight:800;letter-spacing:10px;">${codeBlock}</span>
                </div>
              </div>
              ` : ''}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px 40px 36px;">
              <div style="border-top:1px solid rgba(255,255,255,0.06);padding-top:20px;">
                <p style="margin:0;color:#4A4A5E;font-size:12px;line-height:1.5;text-align:center;">
                  © ${year} ${APP_NAME}. All rights reserved.<br>
                  This is an automated message — please do not reply.
                </p>
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

async function sendVerificationEmail(toEmail: string, code: string, type = 'registration') {
  const subject = type === 'passwordReset'
    ? `${APP_NAME}: Password Reset Code`
    : type === 'login'
      ? `${APP_NAME}: Login Verification Code`
      : `${APP_NAME}: Email Verification Code`;

  const introText = type === 'passwordReset'
    ? 'Use the code below to reset your Kora account password.'
    : type === 'login'
      ? 'A new device is trying to sign in to your Kora account. Use the code below to verify this login.'
      : 'Welcome to Kora! Use the code below to verify your email address and complete your registration.';

  const title = type === 'passwordReset' ? 'Password Reset' : type === 'login' ? 'New Device Login' : 'Verify Your Email';

  const bodyHtml = `<p style="margin:0 0 12px;">${introText}</p>
    <p style="margin:0;color:#6B6B80;font-size:13px;">This code expires in 10 minutes. If you didn't request this, you can safely ignore this email.</p>`;

  const html = premiumEmailTemplate(title, bodyHtml, code);

  await getTransporter().sendMail({
    from: EMAIL_FROM,
    to: toEmail,
    subject,
    html,
    headers: {
      'Date': new Date().toUTCString(),
      'Message-ID': `<${Date.now()}.${Math.random().toString(36).substring(2)}@koramessenger.app>`,
      'Reply-To': EMAIL_FROM,
    },
  });
}

async function sendSecurityAlertEmail(toEmail: string, deviceName: string, action: string, timestamp: string, deviceId?: string, ipAddress?: string) {
  const subject = `${APP_NAME}: Security Alert — ${action}`;

  const bodyHtml = `<p style="margin:0 0 16px;">We detected a security event on your Kora Messenger account:</p>
    <div style="background:rgba(139,92,246,0.08);border:1px solid rgba(139,92,246,0.15);border-radius:12px;padding:16px;margin:0 0 16px;">
      <table cellpadding="0" cellspacing="0" style="width:100%;color:#A0A0B8;font-size:14px;">
        <tr><td style="padding:4px 0;color:#6B6B80;">Action:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${action}</td></tr>
        <tr><td style="padding:4px 0;color:#6B6B80;">Device:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${deviceName}</td></tr>${deviceId ? `
        <tr><td style="padding:4px 0;color:#6B6B80;">Device ID:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${deviceId}</td></tr>` : ''}${ipAddress ? `
        <tr><td style="padding:4px 0;color:#6B6B80;">IP Address:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${ipAddress}</td></tr>` : ''}
        <tr><td style="padding:4px 0;color:#6B6B80;">Time:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${timestamp}</td></tr>
      </table>
    </div>
    <p style="margin:0;color:#6B6B80;font-size:13px;">If this was you, no action is needed. If you don't recognize this activity, please change your password immediately and review your trusted devices in Settings → Account → Security.</p>`;

  const html = premiumEmailTemplate('Security Alert', bodyHtml);

  await getTransporter().sendMail({
    from: EMAIL_FROM,
    to: toEmail,
    subject,
    html,
    headers: {
      'Date': new Date().toUTCString(),
      'Message-ID': `<${Date.now()}.${Math.random().toString(36).substring(2)}@koramessenger.app>`,
      'Reply-To': EMAIL_FROM,
    },
  });
}

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
    // ── SEND CODE ───────────────────────────────────────────
    if (action === 'sendCode') {
      const { email, type = 'registration' } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      if (type === 'registration') {
        const existing = await db.entities.KoraUser.filter({ email });
        if (existing && existing.length > 0) {
          return jsonResponse({ success: false, error: 'An account with this email already exists' });
        }
      }

      if (type === 'login' || type === 'passwordReset') {
        const existing = await db.entities.KoraUser.filter({ email });
        if (!existing || existing.length === 0) {
          return jsonResponse({ success: false, error: 'No account found with this email' });
        }
      }

      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      const oldCodes = await db.entities.VerificationCode.filter({ email, type, used: false });
      if (oldCodes && oldCodes.length > 0) {
        for (const oc of oldCodes) {
          await db.entities.VerificationCode.update(oc.id, { used: true });
        }
      }

      await db.entities.VerificationCode.create({
        email, code, type, expiresAt, used: false, attempts: 0,
      });

      await sendVerificationEmail(email, code, type);
      return jsonResponse({ success: true, message: 'Verification code sent' });
    }

    // ── CHECK USERNAME ─────────────────────────────────────
    if (action === 'checkUsername') {
      const { username } = body;
      if (!username) return jsonResponse({ success: false, error: 'Username is required' });

      const reserved = ['admin','administrator','kora','koramessenger','koraofficial','support','help','system','root','official','team','staff','moderator','mod','settings','about','security','login','register','signup','api','bot','null','undefined','test','demo','info','contact','welcome','home','messenger','founder','ceo','dev','developer','operator','service','page','profile','account','user','me','my','all','new','edit','delete','create','post','message','chat','group','channel','broadcast','notification','verify','auth'];

      const lower = username.toLowerCase();
      if (reserved.includes(lower)) {
        return jsonResponse({ success: true, available: false, reason: 'This username is reserved' });
      }

      const existing = await db.entities.KoraUser.filter({ username: lower });
      if (existing && existing.length > 0) {
        return jsonResponse({ success: true, available: false, reason: 'Username is taken' });
      }
      return jsonResponse({ success: true, available: true });
    }

    // ── VERIFY AND SIGN UP ─────────────────────────────────
    if (action === 'verifyAndSignUp') {
      const { email, code, userData } = body;
      if (!email || !code) return jsonResponse({ success: false, error: 'Email and code are required' });

      const codes = await db.entities.VerificationCode.filter({ email, type: 'registration', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await db.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await db.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await db.entities.VerificationCode.update(matchingCode.id, { used: true });

      const passwordHash = crypto.createHash('sha256').update(userData.password || '').digest('hex');
      const koraId = `KM-${String(Math.floor(100000000 + Math.random() * 900000000))}`;

      const newUser = await db.entities.KoraUser.create({
        email, passwordHash, username: userData.username, koraId,
        fullName: userData.fullName || '', phoneNumber: userData.phoneNumber || '', bio: '', avatarUrl: '', isVerified: true, profileCompleted: false,
      });

      return jsonResponse({ success: true, user: getUserFromRecord(newUser) });
    }

    // ── LOGIN (with device recognition) ────────────────────
    if (action === 'login') {
      const { email, password, deviceId, deviceName, platform } = body;
      if (!email || !password) return jsonResponse({ success: false, error: 'Email and password are required' });

      const passwordHash = crypto.createHash('sha256').update(password).digest('hex');
      const users = await db.entities.KoraUser.filter({ email, passwordHash });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Invalid email or password' });
      }

      const user = getUserFromRecord(users[0]);

      // ── Device recognition ──
      if (deviceId) {
        const trustedDevices = await db.entities.TrustedDevice.filter({ userEmail: email, deviceId });
        if (trustedDevices && trustedDevices.length > 0) {
          const device = trustedDevices[0];
          const now = new Date().toISOString();
          const firstLogin = new Date(device.data?.firstLoginDate || device.firstLoginDate);
          const monthsSinceFirstLogin = (Date.now() - firstLogin.getTime()) / (1000 * 60 * 60 * 24 * 30);

          await db.entities.TrustedDevice.update(device.id, {
            lastLoginDate: now,
            isActive: true,
            isTrusted: monthsSinceFirstLogin >= 1 ? true : (device.data?.isTrusted || device.isTrusted || false),
          });

      // Send login security alert email
      try {
        const _ipAddress = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || req.headers.get('x-real-ip')
          || req.headers.get('cf-connecting-ip')
          || 'Unknown';
        const _loginTimestamp = new Date().toLocaleString('en-US', {
          timeZone: 'UTC',
          dateStyle: 'full',
          timeStyle: 'short',
        });
        await sendSecurityAlertEmail(
          email,
          deviceName || 'Unknown Device',
          'Account Login',
          _loginTimestamp,
          deviceId,
          _ipAddress,
        );
      } catch (e) {
        console.error('Failed to send login security email:', e);
      }

      return jsonResponse({ success: true, user, deviceRecognized: true });
        }
      }

      // Device NOT recognized — send login verification code
      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      const oldCodes = await db.entities.VerificationCode.filter({ email, type: 'login', used: false });
      if (oldCodes && oldCodes.length > 0) {
        for (const oc of oldCodes) {
          await db.entities.VerificationCode.update(oc.id, { used: true });
        }
      }

      await db.entities.VerificationCode.create({
        email, code, type: 'login', expiresAt, used: false, attempts: 0,
      });

      await sendVerificationEmail(email, code, 'login');

      return jsonResponse({
        success: false,
        needsDeviceVerification: true,
        message: 'Verification code sent to your email',
      });
    }

    // ── VERIFY LOGIN (device verification) ──────────────────
    if (action === 'verifyLogin') {
      const { email, code, deviceId, deviceName, platform, recognizeDevice } = body;
      if (!email || !code) return jsonResponse({ success: false, error: 'Email and code are required' });
      if (!deviceId) return jsonResponse({ success: false, error: 'Device ID is required' });

      const codes = await db.entities.VerificationCode.filter({ email, type: 'login', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await db.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await db.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await db.entities.VerificationCode.update(matchingCode.id, { used: true });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const user = getUserFromRecord(users[0]);

      // Save device as trusted if user chose to recognize it
      const now = new Date().toISOString();
      if (recognizeDevice) {
        const existingDevices = await db.entities.TrustedDevice.filter({ userEmail: email, deviceId });
        if (existingDevices && existingDevices.length > 0) {
          await db.entities.TrustedDevice.update(existingDevices[0].id, {
            lastLoginDate: now, isActive: true,
            isTrusted: existingDevices[0].data?.isTrusted || existingDevices[0].isTrusted || false,
          });
        } else {
          await db.entities.TrustedDevice.create({
            userEmail: email, deviceId,
            deviceName: deviceName || 'Unknown Device',
            platform: platform || 'unknown',
            firstLoginDate: now, lastLoginDate: now,
            isTrusted: false, isActive: true,
          });
        }
      }

      // Send login security alert email
      try {
        const _ipAddress = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || req.headers.get('x-real-ip')
          || req.headers.get('cf-connecting-ip')
          || 'Unknown';
        const _loginTimestamp = new Date().toLocaleString('en-US', {
          timeZone: 'UTC',
          dateStyle: 'full',
          timeStyle: 'short',
        });
        await sendSecurityAlertEmail(
          email,
          deviceName || 'Unknown Device',
          'Account Login',
          _loginTimestamp,
          deviceId,
          _ipAddress,
        );
      } catch (e) {
        console.error('Failed to send login security email:', e);
      }
      return jsonResponse({ success: true, user });
    }

    // ── VERIFY CODE (standalone) ────────────────────────────
    if (action === 'verifyCode') {
      const { email, code, type } = body;
      if (!email || !code) return jsonResponse({ success: false, error: 'Email and code are required' });

      const codes = await db.entities.VerificationCode.filter({ email, type: type || 'passwordReset', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await db.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await db.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new code.' });
      }

      // Mark code as used
      await db.entities.VerificationCode.update(matchingCode.id, { used: true });
      return jsonResponse({ success: true, message: 'Code verified' });
    }

    // ── VERIFY AND RESET PASSWORD ──────────────────────────
    if (action === 'verifyAndResetPassword') {
      const { email, code, newPassword } = body;
      if (!email || !code || !newPassword) return jsonResponse({ success: false, error: 'All fields are required' });

      const codes = await db.entities.VerificationCode.filter({ email, type: 'passwordReset', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await db.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await db.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await db.entities.VerificationCode.update(matchingCode.id, { used: true });

      const passwordHash = crypto.createHash('sha256').update(newPassword).digest('hex');
      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      await db.entities.KoraUser.update(users[0].id, { passwordHash });
      return jsonResponse({ success: true, message: 'Password reset successful' });
    }

    // ── SAVE PROFILE ────────────────────────────────────────
    if (action === 'saveProfile') {
      const { userId, fullName, username, bio = '', avatarUrl = '' } = body;
      if (!userId || !fullName || !username) {
        return jsonResponse({ success: false, error: 'Missing required fields' });
      }

      const lowerUsername = username.toLowerCase();
      const existing = await db.entities.KoraUser.filter({ username: lowerUsername });
      if (existing && existing.length > 0 && existing[0].id !== userId) {
        return jsonResponse({ success: false, error: 'Username is already taken' });
      }

      await db.entities.KoraUser.update(userId, {
        fullName, username: lowerUsername, bio, avatarUrl, profileCompleted: true,
      });

      const updated = await db.entities.KoraUser.get(userId);
      return jsonResponse({ success: true, user: getUserFromRecord(updated) });
    }


    // ── GET PROFILE ───────────────────────────────────────
    if (action === "getProfile") {
      const { userId } = body;
      if (!userId) return jsonResponse({ success: false, error: "User ID is required" });
      const user = await db.entities.KoraUser.get(userId);
      if (!user) return jsonResponse({ success: false, error: "Account not found" });
      return jsonResponse({ success: true, user: getUserFromRecord(user) });
    }

    // ── REQUEST ACCOUNT INFO ────────────────────────────────
    if (action === 'requestAccountInfo') {
      const { userId, email } = body;
      if (!userId || !email) return jsonResponse({ success: false, error: 'User ID and email are required' });

      const user = await db.entities.KoraUser.get(userId);
      if (!user) return jsonResponse({ success: false, error: 'Account not found' });

      const userData = getUserFromRecord(user);
      const trustedDevices = await db.entities.TrustedDevice.filter({ userEmail: email });

      return jsonResponse({
        success: true,
        accountCreated: user.created_date || user.createdAt || 'N/A',
        deviceCount: trustedDevices ? trustedDevices.length : 0,
        profile: {
          fullName: userData.fullName,
          username: userData.username,
          koraId: userData.koraId,
          email: userData.email,
          bio: userData.bio,
          avatarUrl: userData.avatarUrl,
          isVerified: userData.isVerified,
          profileCompleted: userData.profileCompleted,
        },
      });
    }

    // ── DELETE ACCOUNT ──────────────────────────────────────
    if (action === 'deleteAccount') {
      const { userId, email } = body;
      if (!userId || !email) return jsonResponse({ success: false, error: 'User ID and email are required' });

      const user = await db.entities.KoraUser.get(userId);
      if (!user) return jsonResponse({ success: false, error: 'Account not found' });

      // Delete trusted devices
      const devices = await db.entities.TrustedDevice.filter({ userEmail: email });
      if (devices && devices.length > 0) {
        for (const device of devices) {
          await db.entities.TrustedDevice.delete(device.id);
        }
      }

      // Delete verification codes
      const codes = await db.entities.VerificationCode.filter({ email });
      if (codes && codes.length > 0) {
        for (const code of codes) {
          await db.entities.VerificationCode.delete(code.id);
        }
      }

      // Delete the user account
      await db.entities.KoraUser.delete(userId);

      return jsonResponse({ success: true, message: 'Account deleted successfully' });
    }

    // ── SAVE BACKUP PIN ──────────────────────────────────────
    if (action === 'saveBackupPin') {
      const { email, pin } = body;
      if (!email || !pin) return jsonResponse({ success: false, error: 'Email and PIN are required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const pinHash = crypto.createHash('sha256').update(pin).digest('hex');
      await db.entities.KoraUser.update(users[0].id, { securePinHash: pinHash });
      return jsonResponse({ success: true, message: 'Backup PIN saved' });
    }

    // ── LOGIN WITH BACKUP PIN ───────────────────────────────
    if (action === 'loginWithBackupPin') {
      const { email, pin, deviceId, deviceName, platform } = body;
      if (!email || !pin) return jsonResponse({ success: false, error: 'Email and PIN are required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Invalid email or PIN' });
      }

      const userRecord = users[0];
      const storedPinHash = userRecord.data?.securePinHash ?? userRecord.securePinHash ?? '';
      if (!storedPinHash) {
        return jsonResponse({ success: false, error: 'No backup PIN set. Please use email and password to log in.' });
      }

      const pinHash = crypto.createHash('sha256').update(pin).digest('hex');
      if (pinHash !== storedPinHash) {
        return jsonResponse({ success: false, error: 'Invalid backup PIN' });
      }

      // PIN is correct — log the user in
      const user = getUserFromRecord(userRecord);

      // Register/update device
      if (deviceId) {
        const trustedDevices = await db.entities.TrustedDevice.filter({ userEmail: email, deviceId });
        if (trustedDevices && trustedDevices.length > 0) {
          const device = trustedDevices[0];
          const now = new Date().toISOString();
          await db.entities.TrustedDevice.update(device.id, {
            lastLoginDate: now,
            isActive: true,
          });
        } else if (deviceName) {
          const now = new Date().toISOString();
          await db.entities.TrustedDevice.create({
            userEmail: email,
            deviceId,
            deviceName,
            platform: platform || 'unknown',
            firstLoginDate: now,
            lastLoginDate: now,
            isActive: true,
            isTrusted: false,
          });
        }
      }

      // Send login security alert email
      try {
        const _ipAddress = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || req.headers.get('x-real-ip')
          || req.headers.get('cf-connecting-ip')
          || 'Unknown';
        const _loginTimestamp = new Date().toLocaleString('en-US', {
          timeZone: 'UTC',
          dateStyle: 'full',
          timeStyle: 'short',
        });
        await sendSecurityAlertEmail(
          email,
          deviceName || 'Unknown Device',
          'Account Login',
          _loginTimestamp,
          deviceId,
          _ipAddress,
        );
      } catch (e) {
        console.error('Failed to send login security email:', e);
      }
      return jsonResponse({ success: true, user });
    }

    // ── SAVE PHONE NUMBER (optional, during onboarding) ────
    if (action === 'savePhoneNumber') {
      const { userId, phoneNumber } = body;
      if (!userId) return jsonResponse({ success: false, error: 'User ID is required' });

      await db.entities.KoraUser.update(userId, { phoneNumber: phoneNumber || '' });
      const updated = await db.entities.KoraUser.get(userId);
      return jsonResponse({ success: true, user: getUserFromRecord(updated) });
    }

    // ── SET PASSKEYS ENABLED (on/off toggle) ────────────────
    if (action === 'setPasskeysEnabled') {
      const { email, enabled } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      await db.entities.KoraUser.update(users[0].id, { passkeysEnabled: !!enabled });
      return jsonResponse({ success: true });
    }

    // ── CREATE PASSKEY ───────────────────────────────────────
    if (action === 'createPasskey') {
      const { email, deviceId, deviceName, platform } = body;
      if (!email || !deviceId) return jsonResponse({ success: false, error: 'Email and device ID are required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      // If a passkey already exists for this device, just refresh it
      const existing = await db.entities.Passkey.filter({ userEmail: email, deviceId });
      if (existing && existing.length > 0) {
        const updated = await db.entities.Passkey.update(existing[0].id, {
          deviceName: deviceName || existing[0].data?.deviceName || existing[0].deviceName || 'Unknown Device',
          platform: platform || existing[0].data?.platform || existing[0].platform || 'unknown',
        });
        return jsonResponse({ success: true, passkey: { id: updated.id, deviceName: updated.data?.deviceName ?? updated.deviceName, platform: updated.data?.platform ?? updated.platform, createdAt: updated.created_date } });
      }

      const created = await db.entities.Passkey.create({
        userEmail: email,
        deviceId,
        deviceName: deviceName || 'Unknown Device',
        platform: platform || 'unknown',
      });

      // Ensure passkeys are marked enabled for the account
      await db.entities.KoraUser.update(users[0].id, { passkeysEnabled: true });

      return jsonResponse({
        success: true,
        passkey: {
          id: created.id,
          deviceName: created.data?.deviceName ?? created.deviceName,
          platform: created.data?.platform ?? created.platform,
          createdAt: created.created_date,
        },
      });
    }

    // ── LIST PASSKEYS ────────────────────────────────────────
    if (action === 'listPasskeys') {
      const { email } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const passkeys = await db.entities.Passkey.filter({ userEmail: email });
      const list = (passkeys || []).map((p: any) => ({
        id: p.id,
        deviceName: p.data?.deviceName ?? p.deviceName ?? 'Unknown Device',
        platform: p.data?.platform ?? p.platform ?? 'unknown',
        createdAt: p.created_date,
      }));

      return jsonResponse({ success: true, passkeys: list });
    }

    // ── DELETE PASSKEY ───────────────────────────────────────
    if (action === 'deletePasskey') {
      const { passkeyId, email } = body;
      if (!passkeyId || !email) return jsonResponse({ success: false, error: 'Passkey ID and email are required' });

      const passkeys = await db.entities.Passkey.filter({ userEmail: email });
      const match = (passkeys || []).find((p: any) => p.id === passkeyId);
      if (!match) {
        return jsonResponse({ success: false, error: 'Passkey not found' });
      }

      await db.entities.Passkey.delete(passkeyId);

      // If no passkeys remain, mark the feature as disabled
      const remaining = await db.entities.Passkey.filter({ userEmail: email });
      if (!remaining || remaining.length === 0) {
        const users = await db.entities.KoraUser.filter({ email });
        if (users && users.length > 0) {
          await db.entities.KoraUser.update(users[0].id, { passkeysEnabled: false });
        }
      }

      return jsonResponse({ success: true, message: 'Passkey deleted' });
    }

    // ── LOGIN WITH PASSKEY ──────────────────────────────────
    if (action === 'loginWithPasskey') {
      const { email, deviceId, deviceName, platform } = body;
      if (!email || !deviceId) return jsonResponse({ success: false, error: 'Email and device ID are required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Invalid email' });
      }

      const userRecord = users[0];
      const passkeysEnabled = userRecord.data?.passkeysEnabled ?? userRecord.passkeysEnabled ?? false;
      if (!passkeysEnabled) {
        return jsonResponse({ success: false, error: 'Passkeys are not enabled for this account' });
      }

      const passkeys = await db.entities.Passkey.filter({ userEmail: email, deviceId });
      if (!passkeys || passkeys.length === 0) {
        return jsonResponse({ success: false, error: 'No passkey found for this device' });
      }

      const user = getUserFromRecord(userRecord);

      // Register/update trusted device (biometric already verified on-device)
      const trustedDevices = await db.entities.TrustedDevice.filter({ userEmail: email, deviceId });
      const now = new Date().toISOString();
      if (trustedDevices && trustedDevices.length > 0) {
        await db.entities.TrustedDevice.update(trustedDevices[0].id, { lastLoginDate: now, isActive: true });
      } else if (deviceName) {
        await db.entities.TrustedDevice.create({
          userEmail: email,
          deviceId,
          deviceName,
          platform: platform || 'unknown',
          firstLoginDate: now,
          lastLoginDate: now,
          isActive: true,
          isTrusted: false,
        });
      }

      // Send login security alert email
      try {
        const _ipAddress = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || req.headers.get('x-real-ip')
          || req.headers.get('cf-connecting-ip')
          || 'Unknown';
        const _loginTimestamp = new Date().toLocaleString('en-US', {
          timeZone: 'UTC',
          dateStyle: 'full',
          timeStyle: 'short',
        });
        await sendSecurityAlertEmail(
          email,
          deviceName || 'Unknown Device',
          'Account Login',
          _loginTimestamp,
          deviceId,
          _ipAddress,
        );
      } catch (e) {
        console.error('Failed to send login security email:', e);
      }
      return jsonResponse({ success: true, user });
    }

    // ── CHECK ACCOUNT SIGN-IN OPTIONS (backup PIN / passkey) ─
    if (action === 'checkSignInOptions') {
      const { email } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      const users = await db.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: true, hasBackupPin: false, passkeysEnabled: false });
      }

      const u = users[0];
      const hasBackupPin = !!(u.data?.securePinHash ?? u.securePinHash);
      const passkeysEnabled = !!(u.data?.passkeysEnabled ?? u.passkeysEnabled);

      return jsonResponse({ success: true, hasBackupPin, passkeysEnabled });
    }

    // ── LOGOUT (send security email) ───────────────────────
    if (action === 'logout') {
      const { email, userId, deviceId, deviceName } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      // Extract client IP from request headers
      const ipAddress = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
        || req.headers.get('x-real-ip')
        || req.headers.get('cf-connecting-ip')
        || 'Unknown';

      const timestamp = new Date().toLocaleString('en-US', {
        timeZone: 'UTC',
        dateStyle: 'full',
        timeStyle: 'short',
      });

      // Send security alert email with device ID and IP
      try {
        await sendSecurityAlertEmail(
          email,
          deviceName || 'Unknown Device',
          'Account Logout',
          timestamp,
          deviceId,
          ipAddress,
        );
      } catch (e) {
        console.error('Failed to send logout email:', e);
      }

      return jsonResponse({ success: true, message: 'Logout email sent' });
    }

    // ── CHECK PHONE NUMBER (is it registered on Kora?) ─────
    if (action === 'checkPhoneNumber') {
      const { phoneNumber } = body;
      if (!phoneNumber) return jsonResponse({ success: false, error: 'Phone number is required' });

      // Normalize: strip spaces, ensure leading +
      let normalized = phoneNumber.replace(/\s+/g, '');
      if (!normalized.startsWith('+') && !normalized.startsWith('0')) {
        normalized = '+' + normalized;
      }

      // Try exact match first, then partial match (last 9+ digits)
      let users = await db.entities.KoraUser.filter({ phoneNumber: normalized });

      if (!users || users.length === 0) {
        // Try without the + prefix
        users = await db.entities.KoraUser.filter({ phoneNumber: normalized.replace(/^\+/, '') });
      }

      if (!users || users.length === 0) {
        // Try matching by last 10 digits (handles different country code formats)
        const last10 = normalized.replace(/\D/g, '').slice(-10);
        if (last10.length >= 9) {
          const allUsers = await db.entities.KoraUser.list();
          const match = allUsers.find((u: any) => {
            const phone = (u.data?.phoneNumber ?? u.phoneNumber ?? '').replace(/\D/g, '');
            return phone.length >= 9 && phone.slice(-10) === last10;
          });
          if (match) {
            return jsonResponse({
              success: true,
              registered: true,
              user: getUserFromRecord(match),
            });
          }
        }
        return jsonResponse({ success: true, registered: false });
      }

      return jsonResponse({
        success: true,
        registered: true,
        user: getUserFromRecord(users[0]),
      });
    }

    // ── CHECK KORA ID ─────────────────────────────────────────
    if (action === 'checkKoraId') {
      const { koraId } = body;
      if (!koraId) return jsonResponse({ success: false, error: 'Kora ID is required' });

      const users = await db.entities.KoraUser.filter({ koraId });
      if (!users || users.length === 0) {
        return jsonResponse({ success: true, registered: false });
      }
      return jsonResponse({
        success: true,
        registered: true,
        user: getUserFromRecord(users[0]),
      });
    }

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