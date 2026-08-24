import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';
import nodemailer from 'npm:nodemailer@6.9.14';

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
      host: SMTP_HOST, port: SMTP_PORT, secure: SMTP_PORT === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });
  }
  return transporter;
}

function emailTemplate(title: string, bodyHtml: string, codeBlock = ''): string {
  const year = new Date().getFullYear();
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#050508;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#050508;min-height:100vh;"><tr><td align="center" style="padding:40px 20px;">
<table width="480" cellpadding="0" cellspacing="0" style="background:linear-gradient(180deg,#0A0A14 0%,#13131F 100%);border-radius:24px;overflow:hidden;box-shadow:0 8px 40px rgba(99,102,241,0.15);">
<tr><td style="background:linear-gradient(135deg,#8B5CF6 0%,#3B82F6 100%);padding:32px 40px;text-align:center;">
<div style="width:56px;height:56px;background:rgba(255,255,255,0.15);border-radius:16px;line-height:56px;color:white;font-size:32px;font-weight:800;margin:0 auto;">K</div>
<h1 style="margin:16px 0 0;color:#FFFFFF;font-size:22px;font-weight:800;letter-spacing:-0.5px;">${APP_NAME}</h1></td></tr>
<tr><td style="padding:36px 40px 20px;">
<h2 style="margin:0 0 16px;color:#FFFFFF;font-size:18px;font-weight:700;">${title}</h2>
<div style="color:#A0A0B8;font-size:15px;line-height:1.6;">${bodyHtml}</div>
${codeBlock ? `<div style="text-align:center;margin:28px 0;"><div style="display:inline-block;padding:22px 44px;background:linear-gradient(135deg,#8B5CF6 0%,#3B82F6 100%);border-radius:18px;box-shadow:0 6px 24px rgba(99,102,241,0.35);"><span style="color:#FFFFFF;font-size:36px;font-weight:800;letter-spacing:10px;">${codeBlock}</span></div></div>` : ''}
</td></tr>
<tr><td style="padding:20px 40px 36px;"><div style="border-top:1px solid rgba(255,255,255,0.06);padding-top:20px;">
<p style="margin:0;color:#4A4A5E;font-size:12px;line-height:1.5;text-align:center;">© ${year} ${APP_NAME}. All rights reserved.<br>This is an automated message — please do not reply.</p>
</div></td></tr></table></td></tr></table></body></html>`;
}

async function sendCodeEmail(toEmail: string, code: string, type: string) {
  const subject = type === 'emailChangeOld' ? `${APP_NAME}: Confirm Email Change` : `${APP_NAME}: Confirm Your New Email`;
  const intro = type === 'emailChangeOld'
    ? 'Someone (hopefully you) is trying to change the email address on your Kora account. Use the code below to authorize this change.'
    : 'Use the code below to confirm this email address for your Kora account.';
  const title = type === 'emailChangeOld' ? 'Confirm Email Change' : 'Confirm Email';
  const body = `<p style="margin:0 0 12px;">${intro}</p><p style="margin:0;color:#6B6B80;font-size:13px;">This code expires in 10 minutes. If you didn't request this, you can safely ignore this email.</p>`;
  await getTransporter().sendMail({
    from: EMAIL_FROM, to: toEmail, subject,
    html: emailTemplate(title, body, code),
    headers: { 'Date': new Date().toUTCString(), 'Message-ID': `<${Date.now()}.${Math.random().toString(36).substring(2)}@koramessenger.app>`, 'Reply-To': EMAIL_FROM },
  });
}

async function sendEmailChangeAlert(toEmail: string, newEmail: string) {
  const ts = new Date().toLocaleString('en-US', { timeZone: 'UTC', dateStyle: 'full', timeStyle: 'short' });
  const body = `<p style="margin:0 0 16px;">Your Kora Messenger email address was recently changed.</p>
    <div style="background:rgba(139,92,246,0.08);border:1px solid rgba(139,92,246,0.15);border-radius:12px;padding:16px;margin:0 0 16px;">
      <table cellpadding="0" cellspacing="0" style="width:100%;color:#A0A0B8;font-size:14px;">
        <tr><td style="padding:4px 0;color:#6B6B80;">Previous email:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${toEmail}</td></tr>
        <tr><td style="padding:4px 0;color:#6B6B80;">New email:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${newEmail}</td></tr>
        <tr><td style="padding:4px 0;color:#6B6B80;">Time:</td><td style="padding:4px 0;color:#FFFFFF;font-weight:600;">${ts}</td></tr>
      </table>
    </div>
    <p style="margin:0;color:#6B6B80;font-size:13px;">If this was you, no action is needed. If you didn't make this change, please secure your account immediately by changing your password and reviewing your trusted devices in Settings → Account → Security.</p>`;
  await getTransporter().sendMail({
    from: EMAIL_FROM, to: toEmail, subject: `${APP_NAME}: Your Email Address Was Updated`,
    html: emailTemplate('Email Updated', body),
    headers: { 'Date': new Date().toUTCString(), 'Message-ID': `<${Date.now()}.${Math.random().toString(36).substring(2)}@koramessenger.app>`, 'Reply-To': EMAIL_FROM },
  });
}

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
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
    // ── INITIATE EMAIL CHANGE (sends code to OLD email) ───────
    if (action === 'initiateEmailChange') {
      const { userId, oldEmail, newEmail } = body;
      if (!userId || !oldEmail || !newEmail) return jsonResponse({ success: false, error: 'User ID, old email, and new email are required' });

      const existing = await db.entities.KoraUser.filter({ email: newEmail });
      if (existing && existing.length > 0 && existing[0].id !== userId) {
        return jsonResponse({ success: false, error: 'An account with this email already exists' });
      }

      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      const oldCodes = await db.entities.VerificationCode.filter({ email: oldEmail, type: 'emailChangeOld', used: false });
      if (oldCodes && oldCodes.length > 0) { for (const oc of oldCodes) { await db.entities.VerificationCode.update(oc.id, { used: true }); } }
      await db.entities.VerificationCode.create({ email: oldEmail, code, type: 'emailChangeOld', expiresAt, used: false, attempts: 0 });
      await sendCodeEmail(oldEmail, code, 'emailChangeOld');
      return jsonResponse({ success: true, message: 'Verification code sent to your current email' });
    }

    // ── RESEND CODE (for old or new email) ────────────────────
    if (action === 'resendEmailChangeCode') {
      const { email, type } = body;
      if (!email || !type) return jsonResponse({ success: false, error: 'Email and type are required' });
      const code = generateCode();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      const oldCodes = await db.entities.VerificationCode.filter({ email, type, used: false });
      if (oldCodes && oldCodes.length > 0) { for (const oc of oldCodes) { await db.entities.VerificationCode.update(oc.id, { used: true }); } }
      await db.entities.VerificationCode.create({ email, code, type, expiresAt, used: false, attempts: 0 });
      await sendCodeEmail(email, code, type);
      return jsonResponse({ success: true, message: 'Code resent' });
    }

    // ── VERIFY OLD EMAIL (then sends code to NEW email) ─────
    if (action === 'verifyOldEmailForChange') {
      const { oldEmail, newEmail, code } = body;
      if (!oldEmail || !newEmail || !code) return jsonResponse({ success: false, error: 'Old email, new email, and code are required' });

      const codes = await db.entities.VerificationCode.filter({ email: oldEmail, type: 'emailChangeOld', used: false });
      if (!codes || codes.length === 0) return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) { await db.entities.VerificationCode.update(recent.id, { used: true }); return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' }); }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) { await db.entities.VerificationCode.update(matchingCode.id, { used: true }); return jsonResponse({ success: false, error: 'Code has expired. Request a new code.' }); }

      await db.entities.VerificationCode.update(matchingCode.id, { used: true });

      // Send code to NEW email
      const newCode = generateCode();
      const newExpiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      const oldNewCodes = await db.entities.VerificationCode.filter({ email: newEmail, type: 'changeEmail', used: false });
      if (oldNewCodes && oldNewCodes.length > 0) { for (const oc of oldNewCodes) { await db.entities.VerificationCode.update(oc.id, { used: true }); } }
      await db.entities.VerificationCode.create({ email: newEmail, code: newCode, type: 'changeEmail', expiresAt: newExpiresAt, used: false, attempts: 0 });
      await sendCodeEmail(newEmail, newCode, 'changeEmail');
      return jsonResponse({ success: true, message: 'Verification code sent to your new email' });
    }

    // ── VERIFY NEW EMAIL AND UPDATE ──────────────────────────
    if (action === 'verifyAndUpdateEmail') {
      const { userId, newEmail, oldEmail, code } = body;
      if (!userId || !newEmail || !code) return jsonResponse({ success: false, error: 'User ID, new email, and code are required' });

      const codes = await db.entities.VerificationCode.filter({ email: newEmail, type: 'changeEmail', used: false });
      if (!codes || codes.length === 0) return jsonResponse({ success: false, error: 'No active verification code. Request a new one.' });

      const matchingCode = codes.find((c: any) => (c.data?.code || c.code) === code);
      if (!matchingCode) {
        const recent = codes[0];
        const attempts = ((recent.data?.attempts || recent.attempts || 0) + 1);
        await db.entities.VerificationCode.update(recent.id, { attempts });
        if (attempts >= 5) { await db.entities.VerificationCode.update(recent.id, { used: true }); return jsonResponse({ success: false, error: 'Too many attempts. Request a new code.' }); }
        return jsonResponse({ success: false, error: 'Invalid verification code' });
      }

      const expiresAt = new Date(matchingCode.data?.expiresAt || matchingCode.expiresAt);
      if (expiresAt < new Date()) { await db.entities.VerificationCode.update(matchingCode.id, { used: true }); return jsonResponse({ success: false, error: 'Code has expired. Request a new code.' }); }

      const existing = await db.entities.KoraUser.filter({ email: newEmail });
      if (existing && existing.length > 0 && existing[0].id !== userId) return jsonResponse({ success: false, error: 'An account with this email already exists' });

      await db.entities.VerificationCode.update(matchingCode.id, { used: true });
      await db.entities.KoraUser.update(userId, { email: newEmail });
      const updated = await db.entities.KoraUser.get(userId);

      // Send security alert to old email
      if (oldEmail) {
        try { await sendEmailChangeAlert(oldEmail, newEmail); } catch (e) { console.error('Failed to send email change alert:', e); }
      }

      return jsonResponse({ success: true, user: getUserFromRecord(updated) });
    }

    return jsonResponse({ success: false, error: `Unknown action: ${action}` });

  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
