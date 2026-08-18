import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';
import nodemailer from 'npm:nodemailer@6.9.14';
import crypto from 'node:crypto';

// ─────────────────────────────────────────────────────────────
//  Domain-swappable config — change these when you get a .com
// ─────────────────────────────────────────────────────────────
const SMTP_HOST = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com';
const SMTP_PORT = parseInt(Deno.env.get('SMTP_PORT') || '587');
const SMTP_USER = Deno.env.get('SMTP_USER') || 'koramessenger.app@gmail.com';
const SMTP_PASS = Deno.env.get('SMTP_PASS') || '';
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') || 'Kora Messenger <koramessenger.app@gmail.com>';
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

async function sendVerificationEmail(toEmail: string, code: string, type = 'registration') {
  const subject = type === 'passwordReset'
    ? `${APP_NAME}: Password Reset Code`
    : type === 'login'
      ? `${APP_NAME}: Login Verification Code`
      : `${APP_NAME}: Email Verification Code`;

  const introText = type === 'passwordReset'
    ? 'Use the code below to reset your password.'
    : type === 'login'
      ? 'Use the code below to verify your login on your new device.'
      : 'Use the code below to verify your email address.';

  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
      <div style="text-align: center; margin-bottom: 32px;">
        <div style="display: inline-block; width: 56px; height: 56px; background: linear-gradient(135deg, #6366F1, #3B82F6); border-radius: 14px; line-height: 56px; color: white; font-size: 32px; font-weight: 800;">K</div>
        <h2 style="margin: 16px 0 0; color: #1a1a2e;">${APP_NAME}</h2>
      </div>
      <p style="color: #333; font-size: 16px; line-height: 1.6;">${introText}</p>
      <div style="text-align: center; margin: 32px 0;">
        <div style="display: inline-block; padding: 20px 40px; background: linear-gradient(135deg, #6366F1, #3B82F6); border-radius: 16px;">
          <span style="color: white; font-size: 36px; font-weight: 800; letter-spacing: 8px;">${code}</span>
        </div>
      </div>
      <p style="color: #666; font-size: 14px; line-height: 1.5;">This code expires in 10 minutes. If you didn't request this, you can safely ignore this email.</p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">
      <p style="color: #999; font-size: 12px; text-align: center;">© ${new Date().getFullYear()} ${APP_NAME}</p>
    </div>
  `;

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
  };
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const body = await req.json();
  const { action } = body;

  try {
    // ── SEND CODE ───────────────────────────────────────────
    if (action === 'sendCode') {
      const { email, type = 'registration' } = body;
      if (!email) return jsonResponse({ success: false, error: 'Email is required' });

      if (type === 'registration') {
        const existing = await base44.entities.KoraUser.filter({ email });
        if (existing && existing.length > 0) {
          return jsonResponse({ success: false, error: 'An account with this email already exists' });
        }
      }

      if (type === 'login' || type === 'passwordReset') {
        const existing = await base44.entities.KoraUser.filter({ email });
        if (!existing || existing.length === 0) {
          return jsonResponse({ success: false, error: 'No account found with this email' });
        }
      }

      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      const oldCodes = await base44.entities.VerificationCode.filter({ email, type, used: false });
      if (oldCodes && oldCodes.length > 0) {
        for (const oc of oldCodes) {
          await base44.entities.VerificationCode.update(oc.id, { used: true });
        }
      }

      await base44.entities.VerificationCode.create({
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

      const existing = await base44.entities.KoraUser.filter({ username: lower });
      if (existing && existing.length > 0) {
        return jsonResponse({ success: true, available: false, reason: 'Username is taken' });
      }
      return jsonResponse({ success: true, available: true });
    }

    // ── VERIFY AND SIGN UP ─────────────────────────────────
    if (action === 'verifyAndSignUp') {
      const { email, code, userData } = body;
      if (!email || !code) return jsonResponse({ success: false, error: 'Email and code are required' });

      const codes = await base44.entities.VerificationCode.filter({ email, type: 'registration', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await base44.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await base44.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await base44.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await base44.entities.VerificationCode.update(matchingCode.id, { used: true });

      const passwordHash = crypto.createHash('sha256').update(userData.password || '').digest('hex');
      const koraId = `KM-${String(Math.floor(100000000 + Math.random() * 900000000))}`;

      const newUser = await base44.entities.KoraUser.create({
        email, passwordHash, username: userData.username, koraId,
        fullName: '', bio: '', avatarUrl: '', isVerified: true, profileCompleted: false,
      });

      return jsonResponse({ success: true, user: getUserFromRecord(newUser) });
    }

    // ── LOGIN (with device recognition) ────────────────────
    if (action === 'login') {
      const { email, password, deviceId, deviceName, platform } = body;
      if (!email || !password) return jsonResponse({ success: false, error: 'Email and password are required' });

      const passwordHash = crypto.createHash('sha256').update(password).digest('hex');
      const users = await base44.entities.KoraUser.filter({ email, passwordHash });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Invalid email or password' });
      }

      const user = getUserFromRecord(users[0]);

      // ── Device recognition ──
      if (deviceId) {
        const trustedDevices = await base44.entities.TrustedDevice.filter({ userEmail: email, deviceId });
        if (trustedDevices && trustedDevices.length > 0) {
          const device = trustedDevices[0];
          const now = new Date().toISOString();
          const firstLogin = new Date(device.data?.firstLoginDate || device.firstLoginDate);
          const monthsSinceFirstLogin = (Date.now() - firstLogin.getTime()) / (1000 * 60 * 60 * 24 * 30);

          await base44.entities.TrustedDevice.update(device.id, {
            lastLoginDate: now,
            isActive: true,
            isTrusted: monthsSinceFirstLogin >= 1 ? true : (device.data?.isTrusted || device.isTrusted || false),
          });

          return jsonResponse({ success: true, user, deviceRecognized: true });
        }
      }

      // Device NOT recognized — send login verification code
      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      const oldCodes = await base44.entities.VerificationCode.filter({ email, type: 'login', used: false });
      if (oldCodes && oldCodes.length > 0) {
        for (const oc of oldCodes) {
          await base44.entities.VerificationCode.update(oc.id, { used: true });
        }
      }

      await base44.entities.VerificationCode.create({
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

      const codes = await base44.entities.VerificationCode.filter({ email, type: 'login', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await base44.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await base44.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await base44.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await base44.entities.VerificationCode.update(matchingCode.id, { used: true });

      const users = await base44.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      const user = getUserFromRecord(users[0]);

      // Save device as trusted if user chose to recognize it
      const now = new Date().toISOString();
      if (recognizeDevice) {
        const existingDevices = await base44.entities.TrustedDevice.filter({ userEmail: email, deviceId });
        if (existingDevices && existingDevices.length > 0) {
          await base44.entities.TrustedDevice.update(existingDevices[0].id, {
            lastLoginDate: now, isActive: true,
            isTrusted: existingDevices[0].data?.isTrusted || existingDevices[0].isTrusted || false,
          });
        } else {
          await base44.entities.TrustedDevice.create({
            userEmail: email, deviceId,
            deviceName: deviceName || 'Unknown Device',
            platform: platform || 'unknown',
            firstLoginDate: now, lastLoginDate: now,
            isTrusted: false, isActive: true,
          });
        }
      }

      return jsonResponse({ success: true, user });
    }

    // ── VERIFY AND RESET PASSWORD ──────────────────────────
    if (action === 'verifyAndResetPassword') {
      const { email, code, newPassword } = body;
      if (!email || !code || !newPassword) return jsonResponse({ success: false, error: 'All fields are required' });

      const codes = await base44.entities.VerificationCode.filter({ email, type: 'passwordReset', used: false });
      if (!codes || codes.length === 0) {
        return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });
      }

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await base44.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) {
          await base44.entities.VerificationCode.update(recent.id, { used: true });
          return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' });
        }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) {
        await base44.entities.VerificationCode.update(matchingCode.id, { used: true });
        return jsonResponse({ success: false, error: 'Code has expired. Request a new one.' });
      }

      await base44.entities.VerificationCode.update(matchingCode.id, { used: true });

      const passwordHash = crypto.createHash('sha256').update(newPassword).digest('hex');
      const users = await base44.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return jsonResponse({ success: false, error: 'Account not found' });
      }

      await base44.entities.KoraUser.update(users[0].id, { passwordHash });
      return jsonResponse({ success: true, message: 'Password reset successful' });
    }

    // ── SAVE PROFILE ────────────────────────────────────────
    if (action === 'saveProfile') {
      const { userId, fullName, username, bio = '', avatarUrl = '' } = body;
      if (!userId || !fullName || !username) {
        return jsonResponse({ success: false, error: 'Missing required fields' });
      }

      const lowerUsername = username.toLowerCase();
      const existing = await base44.entities.KoraUser.filter({ username: lowerUsername });
      if (existing && existing.length > 0 && existing[0].id !== userId) {
        return jsonResponse({ success: false, error: 'Username is already taken' });
      }

      await base44.entities.KoraUser.update(userId, {
        fullName, username: lowerUsername, bio, avatarUrl, profileCompleted: true,
      });

      const updated = await base44.entities.KoraUser.get(userId);
      return jsonResponse({ success: true, user: getUserFromRecord(updated) });
    }

    return jsonResponse({ success: false, error: `Unknown action: ${action}` });
  } catch (error: any) {
    console.error('koraAuth error:', error);
    return jsonResponse({ success: false, error: error.message || 'Internal server error' }, 500);
  }
});
