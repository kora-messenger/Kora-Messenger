const nodemailer = require('nodemailer');

// Delivery chain: Brevo HTTPS API -> SMTP -> dev console log.
// Render's free tier blocks outbound SMTP (25/465/587), so HTTPS
// APIs are the only zero-cost option there. The SMTP path stays for
// future self-hosted infrastructure (VPS / paid tier), keeping the
// mailer domain-swappable.

const SUBJECTS = {
  registration: 'Your Kora verification code',
  login: 'Your Kora login code',
  passwordReset: 'Your Kora password reset code',
  phone_change: 'Your Kora phone change code',
  email_change: 'Your Kora email change code',
};

const brevoConfigured = () => Boolean(process.env.BREVO_API_KEY);

const smtpConfigured = () =>
  Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);

let transporter = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: Number(process.env.SMTP_PORT) === 465,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
      // Render instances have no IPv6 egress; force IPv4 or the SMTP
      // handshake fails with ENETUNREACH/ETIMEDOUT on Gmail's AAAA record.
      family: 4,
      connectionTimeout: 30000,
    });
  }
  return transporter;
}

function codeText(code) {
  return `Your Kora verification code is: ${code}\n\nIt expires in 10 minutes. If you didn't request it, you can ignore this email.`;
}

function codeHtml(code) {
  return `<div style="font-family:Segoe UI,Roboto,Arial,sans-serif;max-width:420px;margin:0 auto;padding:32px;background:#0B0E14;color:#fff;border-radius:16px">
      <h2 style="margin:0 0 8px;color:#fff">Kora Messenger</h2>
      <p style="color:#9AA4B2;margin:0 0 24px">Your verification code is:</p>
      <div style="font-size:36px;font-weight:700;letter-spacing:8px;background:linear-gradient(90deg,#6C63FF,#4A90D9);-webkit-background-clip:text;background-clip:text;color:transparent">${code}</div>
      <p style="color:#9AA4B2;font-size:13px;margin-top:24px">This code expires in 10 minutes. If you didn't request it, you can ignore this email.</p>
    </div>`;
}

/// Sends the 6-digit code to the user's email.
/// Returns { delivered: true } or { delivered: false, reason }.
/// When nothing is configured, the code is logged to the server
/// console instead (dev mode) so the flow is still testable.
async function sendVerificationCode(email, code, type) {
  const subject = SUBJECTS[type] || SUBJECTS.registration;
  const fromEmail = process.env.BREVO_SENDER_EMAIL || process.env.SMTP_USER || 'no-reply@koramessenger.com';
  const fromName = process.env.BREVO_SENDER_NAME || 'Kora Messenger';

  if (brevoConfigured()) {
    try {
      const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'api-key': process.env.BREVO_API_KEY,
          'content-type': 'application/json',
          accept: 'application/json',
        },
        body: JSON.stringify({
          sender: { email: fromEmail, name: fromName },
          to: [{ email }],
          subject,
          textContent: codeText(code),
          htmlContent: codeHtml(code),
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (resp.ok) return { delivered: true, via: 'brevo' };
      const errText = await resp.text();
      console.error(`[mailer] Brevo API error ${resp.status} for ${email}: ${errText}`);
      return { delivered: false, reason: `brevo_http_${resp.status}` };
    } catch (err) {
      console.error(`[mailer] Brevo request failed for ${email}:`, err.message);
      return { delivered: false, reason: 'brevo_unreachable' };
    }
  }

  if (smtpConfigured()) {
    await getTransporter().sendMail({
      from: `${fromName} <${fromEmail}>`,
      to: email,
      subject,
      text: codeText(code),
      html: codeHtml(code),
    });
    return { delivered: true, via: 'smtp' };
  }

  console.log(`[mailer:DEV] verification code for ${email} (${type}): ${code}`);
  return { delivered: false, reason: 'smtp_not_configured' };
}

module.exports = { sendVerificationCode, smtpConfigured, brevoConfigured };
