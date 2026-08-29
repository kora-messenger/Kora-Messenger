import { Router } from 'express';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import nodemailer from 'nodemailer';
import config from '../config.js';
import {
  KoraUser,
  VerificationCode,
  TrustedDevice,
  Passkey,
  SuspensionRecord,
  Conversation,
  ChatMessage,
} from '../models/index.js';

const router = Router();

// ─────────────────────────────────────────────────────────────
//  Nodemailer Transporter Setup
// ─────────────────────────────────────────────────────────────
let transporter = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: config.smtp.host || 'smtp.gmail.com',
      port: config.smtp.port || 587,
      secure: (config.smtp.port === 465),
      auth: (config.smtp.user && config.smtp.pass) ? {
        user: config.smtp.user,
        pass: config.smtp.pass,
      } : undefined,
    });
  }
  return transporter;
}

// ─────────────────────────────────────────────────────────────
//  Premium HTML Email Template
// ─────────────────────────────────────────────────────────────
function premiumEmailTemplate(title, bodyHtml, codeBlock = '') {
  const year = new Date().getFullYear();
  const appName = config.appName || 'Kora Messenger';
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
              <h1 style="margin:16px 0 0;color:#FFFFFF;font-size:22px;font-weight:800;letter-spacing:-0.5px;">${appName}</h1>
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
                  © ${year} ${appName}. All rights reserved.<br>
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

// ─────────────────────────────────────────────────────────────
//  Send Verification Email
// ─────────────────────────────────────────────────────────────
async function sendVerificationEmail(toEmail, code, type = 'registration') {
  const appName = config.appName || 'Kora Messenger';
  const subject = type === 'passwordReset'
    ? `${appName}: Password Reset Code`
    : type === 'login'
      ? `${appName}: Login Verification Code`
      : type === 'changeEmail'
        ? `${appName}: Confirm Your New Email`
        : `${appName}: Email Verification Code`;

  const introText = type === 'passwordReset'
    ? 'Use the code below to reset your Kora account password.'
    : type === 'login'
      ? 'A new device is trying to sign in to your Kora account. Use the code below to verify this login.'
      : type === 'changeEmail'
        ? 'Use the code below to confirm this email address for your Kora account.'
        : 'Welcome to Kora! Use the code below to verify your email address and complete your registration.';

  const title = type === 'passwordReset'
    ? 'Password Reset'
    : type === 'login'
      ? 'New Device Login'
      : type === 'changeEmail'
        ? 'Confirm Email'
        : 'Verify Your Email';

  const bodyHtml = `<p style="margin:0 0 12px;">${introText}</p>
    <p style="margin:0;color:#6B6B80;font-size:13px;">This code expires in 10 minutes. If you didn't request this, you can safely ignore this email.</p>`;

  const html = premiumEmailTemplate(title, bodyHtml, code);
  const from = config.smtp?.from || `Kora Messenger <noreply@koramessenger.app>`;

  try {
    await getTransporter().sendMail({
      from,
      to: toEmail,
      subject,
      html,
    });
  } catch (err) {
    console.error('[Nodemailer Error] Failed to send verification email:', err);
  }
}

// ─────────────────────────────────────────────────────────────
//  Send Welcome Email
// ─────────────────────────────────────────────────────────────
async function sendWelcomeEmail(toEmail, fullName) {
  const appName = config.appName || 'Kora Messenger';
  const subject = 'Welcome to Kora Messenger 🎉';
  const displayName = fullName || 'there';

  const bodyHtml = `<p style="margin:0 0 16px;">Welcome to Kora, ${displayName}! 👋</p>
    <p style="margin:0 0 16px;">We're excited to have you with us.</p>
    <p style="margin:0 0 16px;">Your Kora account has been successfully created.</p>
    <div style="background:linear-gradient(135deg,rgba(139,92,246,0.12) 0%,rgba(59,130,246,0.12) 100%);border:1px solid rgba(139,92,246,0.2);border-radius:16px;padding:20px;margin:0 0 20px;text-align:center;">
      <p style="margin:0 0 8px;font-size:20px;">🎁</p>
      <p style="margin:0 0 4px;color:#FFFFFF;font-size:18px;font-weight:700;">7 Days of Kora Premium — FREE</p>
      <p style="margin:0;color:#A0A0B8;font-size:14px;">Your Premium experience is now available through your Kora account.</p>
    </div>
    <p style="margin:0 0 8px;">Open Kora and start exploring.</p>
    <div style="text-align:center;margin:24px 0;">
      <a href="${config.frontendUrl || 'https://koramessenger.app'}" style="display:inline-block;padding:14px 36px;background:linear-gradient(135deg,#8B5CF6 0%,#3B82F6 100%);border-radius:14px;color:#FFFFFF;text-decoration:none;font-size:16px;font-weight:600;box-shadow:0 4px 20px rgba(99,102,241,0.3);">Open Kora Messenger</a>
    </div>
    <p style="margin:16px 0 0;color:#A0A0B8;font-size:15px;">Welcome to the Kora community. 💜</p>`;

  const html = premiumEmailTemplate('Welcome to Kora!', bodyHtml);
  const from = config.smtp?.from || `Kora Messenger <noreply@koramessenger.app>`;

  try {
    await getTransporter().sendMail({
      from,
      to: toEmail,
      subject,
      html,
    });
  } catch (err) {
    console.error('[Nodemailer Error] Failed to send welcome email:', err);
  }
}

// ─────────────────────────────────────────────────────────────
//  Password & PIN Hashing Helpers (crypto.scryptSync)
// ─────────────────────────────────────────────────────────────
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derivedKey = crypto.scryptSync(password, salt, 64);
  return `${salt}:${derivedKey.toString('hex')}`;
}

function verifyPassword(password, storedHash) {
  if (!storedHash) return false;
  if (storedHash.includes(':')) {
    const [salt, hash] = storedHash.split(':');
    const derivedKey = crypto.scryptSync(password, salt, 64);
    const keyBuffer = Buffer.from(hash, 'hex');
    if (derivedKey.length !== keyBuffer.length) return false;
    return crypto.timingSafeEqual(derivedKey, keyBuffer);
  }
  // Fallback if legacy SHA-256 hash was stored
  const sha256Hash = crypto.createHash('sha256').update(password).digest('hex');
  return sha256Hash === storedHash;
}

function hashPin(pin) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derivedKey = crypto.scryptSync(pin, salt, 64);
  return `${salt}:${derivedKey.toString('hex')}`;
}

function verifyPin(pin, storedHash) {
  if (!storedHash) return false;
  if (storedHash.includes(':')) {
    const [salt, hash] = storedHash.split(':');
    const derivedKey = crypto.scryptSync(pin, salt, 64);
    const keyBuffer = Buffer.from(hash, 'hex');
    if (derivedKey.length !== keyBuffer.length) return false;
    return crypto.timingSafeEqual(derivedKey, keyBuffer);
  }
  return false;
}

// ─────────────────────────────────────────────────────────────
//  JWT & Auth Helpers
// ─────────────────────────────────────────────────────────────
function generateToken(user) {
  const secret = config.jwtSecret || config.JWT_SECRET || 'default_secret_key';
  return jwt.sign(
    {
      id: user._id ? user._id.toString() : user.id,
      email: user.email,
      username: user.username,
      koraId: user.koraId,
    },
    secret,
    { expiresIn: '30d' }
  );
}

function verifyToken(token) {
  if (!token) return null;
  try {
    const secret = config.jwtSecret || config.JWT_SECRET || 'default_secret_key';
    return jwt.verify(token, secret);
  } catch (err) {
    return null;
  }
}

function getTokenFromReq(req) {
  if (req.body && req.body.token) return req.body.token;
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  return null;
}

async function authenticateRequest(req) {
  const token = getTokenFromReq(req);
  if (!token) return null;
  const decoded = verifyToken(token);
  if (!decoded) return null;

  let user = null;
  if (decoded.id) {
    try {
      user = await KoraUser.findById(decoded.id);
    } catch (e) {
      // Invalid ObjectId fallback
    }
  }
  if (!user && decoded.email) {
    user = await KoraUser.findOne({ email: decoded.email.toLowerCase().trim() });
  }
  return user;
}

// ─────────────────────────────────────────────────────────────
//  User Formatting Helper
// ─────────────────────────────────────────────────────────────
function computeIsPremium(user) {
  if (!user.isPremium) return false;
  if (user.premiumSource === 'owner_override') return true;
  if (!user.premiumExpiresAt) return true;
  return new Date(user.premiumExpiresAt).getTime() > Date.now();
}

function getUserFromRecord(user) {
  return {
    id: user._id ? user._id.toString() : user.id,
    email: user.email || '',
    username: user.username || '',
    koraId: user.koraId || '',
    fullName: user.fullName || '',
    bio: user.bio || '',
    avatarUrl: user.avatarUrl || '',
    isVerified: user.isVerified ?? true,
    profileCompleted: user.profileCompleted ?? false,
    phoneNumber: user.phoneNumber || '',
    isPremium: computeIsPremium(user),
    premiumExpiresAt: user.premiumExpiresAt || null,
    premiumSource: user.premiumSource || '',
    passkeysEnabled: user.passkeysEnabled ?? false,
    isSuspended: user.isSuspended ?? false,
  };
}

// ─────────────────────────────────────────────────────────────
//  Main Express Router - Action Handler
// ─────────────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  try {
    const { action } = req.body;
    if (!action) {
      return res.status(400).json({ success: false, error: 'Action is required' });
    }

    switch (action) {

      // 1. sendCode
      case 'sendCode': {
        const { email, type = 'registration' } = req.body;
        if (!email) return res.status(400).json({ success: false, error: 'Email is required' });

        const cleanEmail = email.toLowerCase().trim();

        if (type === 'registration' || type === 'changeEmail') {
          const existing = await KoraUser.findOne({ email: cleanEmail });
          if (existing) {
            return res.status(400).json({ success: false, error: 'An account with this email already exists' });
          }
        }

        if (type === 'login' || type === 'passwordReset') {
          const existing = await KoraUser.findOne({ email: cleanEmail });
          if (!existing) {
            return res.status(400).json({ success: false, error: 'No account found with this email' });
          }
        }

        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

        await VerificationCode.updateMany(
          { email: cleanEmail, type, used: false },
          { $set: { used: true } }
        );

        await VerificationCode.create({
          email: cleanEmail,
          code,
          type,
          expiresAt,
          used: false,
          attempts: 0,
        });

        await sendVerificationEmail(cleanEmail, code, type);
        return res.json({ success: true, message: 'Verification code sent' });
      }

      // 2. checkUsername
      case 'checkUsername': {
        const { username } = req.body;
        if (!username) return res.status(400).json({ success: false, error: 'Username is required' });

        const reserved = [
          'admin','administrator','kora','koramessenger','koraofficial','support','help','system','root','official','team','staff','moderator','mod','settings','about','security','login','register','signup','api','bot','null','undefined','test','demo','info','contact','welcome','home','messenger','founder','ceo','dev','developer','operator','service','page','profile','account','user','me','my','all','new','edit','delete','create','post','message','chat','group','channel','broadcast','notification','verify','auth'
        ];

        const lower = username.toLowerCase().trim();
        if (reserved.includes(lower)) {
          return res.json({ success: true, available: false, reason: 'This username is reserved' });
        }

        const existing = await KoraUser.findOne({ username: lower });
        if (existing) {
          return res.json({ success: true, available: false, reason: 'Username is taken' });
        }

        return res.json({ success: true, available: true });
      }

      // 3. verifyAndSignUp
      case 'verifyAndSignUp': {
        const email = req.body.email ? req.body.email.toLowerCase().trim() : '';
        const code = req.body.code;
        const username = req.body.username || req.body.userData?.username;
        const password = req.body.password || req.body.userData?.password;
        const fullName = req.body.fullName || req.body.userData?.fullName;
        const koraId = req.body.koraId || req.body.userData?.koraId || `KM-${Math.floor(100000000 + Math.random() * 900000000)}`;

        if (!email || !code) return res.status(400).json({ success: false, error: 'Email and code are required' });

        const codes = await VerificationCode.find({ email, type: 'registration', used: false }).sort({ createdAt: -1 });
        if (!codes || codes.length === 0) {
          return res.status(400).json({ success: false, error: 'No active verification code. Request a new one.' });
        }

        const matchingCode = codes.find(c => c.code === code);
        if (!matchingCode) {
          const recent = codes[0];
          recent.attempts = (recent.attempts || 0) + 1;
          if (recent.attempts >= 5) {
            recent.used = true;
          }
          await recent.save();
          if (recent.attempts >= 5) {
            return res.status(400).json({ success: false, error: 'Too many attempts. Request a new code.' });
          }
          return res.status(400).json({ success: false, error: 'Invalid verification code' });
        }

        if (new Date(matchingCode.expiresAt) < new Date()) {
          matchingCode.used = true;
          await matchingCode.save();
          return res.status(400).json({ success: false, error: 'Code has expired. Request a new one.' });
        }

        matchingCode.used = true;
        await matchingCode.save();

        const passwordHash = hashPassword(password || '');
        const trialExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

        const newUser = await KoraUser.create({
          email,
          passwordHash,
          username: username ? username.toLowerCase().trim() : undefined,
          koraId,
          fullName: fullName || '',
          isVerified: true,
          profileCompleted: false,
          isPremium: true,
          premiumExpiresAt: trialExpiry,
          premiumSource: 'trial',
        });

        sendWelcomeEmail(email, fullName || '').catch(err => console.error('[Welcome Email Error]', err));

        const token = generateToken(newUser);
        return res.json({ success: true, token, user: getUserFromRecord(newUser) });
      }

      // 4. login
      case 'login': {
        const { email, password, deviceId, deviceName, platform } = req.body;
        if (!email || !password) return res.status(400).json({ success: false, error: 'Email and password are required' });

        const cleanEmail = email.toLowerCase().trim();
        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) {
          return res.status(401).json({ success: false, error: 'Invalid email or password' });
        }

        if (!verifyPassword(password, user.passwordHash)) {
          return res.status(401).json({ success: false, error: 'Invalid email or password' });
        }

        // Check suspension
        if (user.isSuspended) {
          if (user.suspensionExpiresAt && new Date(user.suspensionExpiresAt) < new Date()) {
            user.isSuspended = false;
            await user.save();
          } else {
            return res.status(403).json({
              success: false,
              error: 'Account is suspended',
              reason: user.suspensionReason || 'Account suspended',
            });
          }
        }

        // Device recognition
        if (deviceId) {
          const trustedDevice = await TrustedDevice.findOne({ userEmail: cleanEmail, deviceId });
          if (trustedDevice) {
            trustedDevice.lastLoginDate = new Date();
            trustedDevice.isActive = true;
            await trustedDevice.save();

            const token = generateToken(user);
            return res.json({
              success: true,
              token,
              user: getUserFromRecord(user),
              deviceRecognized: true,
            });
          }
        }

        // Send login verification code if device unrecognized
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

        await VerificationCode.updateMany(
          { email: cleanEmail, type: 'login', used: false },
          { $set: { used: true } }
        );

        await VerificationCode.create({
          email: cleanEmail,
          code,
          type: 'login',
          expiresAt,
          used: false,
          attempts: 0,
        });

        await sendVerificationEmail(cleanEmail, code, 'login');

        return res.json({
          success: false,
          needsDeviceVerification: true,
          message: 'Verification code sent to your email',
        });
      }

      // 5. verifyLogin
      case 'verifyLogin': {
        const { email, code, deviceId, deviceName, platform, recognizeDevice } = req.body;
        if (!email || !code) return res.status(400).json({ success: false, error: 'Email and code are required' });

        const cleanEmail = email.toLowerCase().trim();
        const codes = await VerificationCode.find({ email: cleanEmail, type: 'login', used: false }).sort({ createdAt: -1 });
        if (!codes || codes.length === 0) {
          return res.status(400).json({ success: false, error: 'No active verification code. Request a new one.' });
        }

        const matchingCode = codes.find(c => c.code === code);
        if (!matchingCode) {
          const recent = codes[0];
          recent.attempts = (recent.attempts || 0) + 1;
          if (recent.attempts >= 5) recent.used = true;
          await recent.save();
          if (recent.attempts >= 5) {
            return res.status(400).json({ success: false, error: 'Too many attempts. Request a new code.' });
          }
          return res.status(400).json({ success: false, error: 'Invalid verification code' });
        }

        if (new Date(matchingCode.expiresAt) < new Date()) {
          matchingCode.used = true;
          await matchingCode.save();
          return res.status(400).json({ success: false, error: 'Code has expired. Request a new one.' });
        }

        matchingCode.used = true;
        await matchingCode.save();

        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) return res.status(404).json({ success: false, error: 'Account not found' });

        if (user.isSuspended) {
          if (user.suspensionExpiresAt && new Date(user.suspensionExpiresAt) < new Date()) {
            user.isSuspended = false;
            await user.save();
          } else {
            return res.status(403).json({ success: false, error: 'Account is suspended' });
          }
        }

        const now = new Date();
        if (deviceId) {
          await TrustedDevice.findOneAndUpdate(
            { userEmail: cleanEmail, deviceId },
            {
              userEmail: cleanEmail,
              deviceId,
              deviceName: deviceName || 'Unknown Device',
              platform: platform || 'unknown',
              lastLoginDate: now,
              isActive: true,
              isTrusted: !!recognizeDevice,
              $setOnInsert: { firstLoginDate: now },
            },
            { upsert: true, new: true }
          );
        }

        const token = generateToken(user);
        return res.json({ success: true, token, user: getUserFromRecord(user) });
      }

      // 6. verifyCode
      case 'verifyCode': {
        const { email, code, type = 'registration' } = req.body;
        if (!email || !code) return res.status(400).json({ success: false, error: 'Email and code are required' });

        const cleanEmail = email.toLowerCase().trim();
        const codes = await VerificationCode.find({ email: cleanEmail, type, used: false }).sort({ createdAt: -1 });
        if (!codes || codes.length === 0) {
          return res.status(400).json({ success: false, error: 'No active verification code' });
        }

        const matchingCode = codes.find(c => c.code === code);
        if (!matchingCode) {
          const recent = codes[0];
          recent.attempts = (recent.attempts || 0) + 1;
          if (recent.attempts >= 5) recent.used = true;
          await recent.save();
          if (recent.attempts >= 5) {
            return res.status(400).json({ success: false, error: 'Too many attempts' });
          }
          return res.status(400).json({ success: false, error: 'Invalid verification code' });
        }

        if (new Date(matchingCode.expiresAt) < new Date()) {
          matchingCode.used = true;
          await matchingCode.save();
          return res.status(400).json({ success: false, error: 'Code has expired' });
        }

        return res.json({ success: true, message: 'Code is valid' });
      }

      // 7. verifyAndResetPassword
      case 'verifyAndResetPassword': {
        const { email, code, newPassword } = req.body;
        if (!email || !code || !newPassword) {
          return res.status(400).json({ success: false, error: 'Email, code, and new password are required' });
        }

        const cleanEmail = email.toLowerCase().trim();
        const codes = await VerificationCode.find({ email: cleanEmail, type: 'passwordReset', used: false }).sort({ createdAt: -1 });
        if (!codes || codes.length === 0) {
          return res.status(400).json({ success: false, error: 'No active verification code' });
        }

        const matchingCode = codes.find(c => c.code === code);
        if (!matchingCode) {
          const recent = codes[0];
          recent.attempts = (recent.attempts || 0) + 1;
          if (recent.attempts >= 5) recent.used = true;
          await recent.save();
          return res.status(400).json({ success: false, error: 'Invalid verification code' });
        }

        if (new Date(matchingCode.expiresAt) < new Date()) {
          matchingCode.used = true;
          await matchingCode.save();
          return res.status(400).json({ success: false, error: 'Code has expired' });
        }

        matchingCode.used = true;
        await matchingCode.save();

        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) return res.status(404).json({ success: false, error: 'Account not found' });

        user.passwordHash = hashPassword(newPassword);
        await user.save();

        return res.json({ success: true, message: 'Password reset successfully' });
      }

      // 8. saveProfile
      case 'saveProfile': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { fullName, bio, avatarUrl, username, phoneNumber } = req.body;

        if (username && username.toLowerCase().trim() !== user.username) {
          const cleanUsername = username.toLowerCase().trim();
          const existing = await KoraUser.findOne({ username: cleanUsername });
          if (existing && existing._id.toString() !== user._id.toString()) {
            return res.status(400).json({ success: false, error: 'Username is already taken' });
          }
          user.username = cleanUsername;
        }

        if (fullName !== undefined) user.fullName = fullName;
        if (bio !== undefined) user.bio = bio;
        if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;
        if (phoneNumber !== undefined) user.phoneNumber = phoneNumber;

        if (user.fullName || user.bio || user.avatarUrl) {
          user.profileCompleted = true;
        }

        await user.save();
        return res.json({ success: true, user: getUserFromRecord(user) });
      }

      // 9. getProfile
      case 'getProfile': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        return res.json({ success: true, user: getUserFromRecord(user) });
      }

      // 10. requestAccountInfo
      case 'requestAccountInfo': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const devices = await TrustedDevice.find({ userEmail: user.email });
        const passkeys = await Passkey.find({ userEmail: user.email });

        return res.json({
          success: true,
          user: getUserFromRecord(user),
          userData: getUserFromRecord(user),
          devices,
          passkeys,
        });
      }

      // 11. deleteAccount
      case 'deleteAccount': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const userEmail = user.email;

        await KoraUser.deleteOne({ _id: user._id });
        await VerificationCode.deleteMany({ email: userEmail });
        await TrustedDevice.deleteMany({ userEmail });
        await Passkey.deleteMany({ userEmail });
        await SuspensionRecord.deleteMany({ userEmail });
        await Conversation.deleteMany({ userEmail });
        await ChatMessage.deleteMany({ userEmail });

        return res.json({ success: true, message: 'Account and associated data deleted' });
      }

      // 12. saveBackupPin
      case 'saveBackupPin': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { pin } = req.body;
        if (!pin) return res.status(400).json({ success: false, error: 'PIN is required' });

        user.securePinHash = hashPin(pin);
        await user.save();

        return res.json({ success: true, message: 'Backup PIN saved successfully' });
      }

      // 13. loginWithBackupPin
      case 'loginWithBackupPin': {
        const { email, pin, deviceId, deviceName, platform } = req.body;
        if (!email || !pin) return res.status(400).json({ success: false, error: 'Email and PIN are required' });

        const cleanEmail = email.toLowerCase().trim();
        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) return res.status(404).json({ success: false, error: 'Account not found' });

        if (user.isSuspended) {
          if (user.suspensionExpiresAt && new Date(user.suspensionExpiresAt) < new Date()) {
            user.isSuspended = false;
            await user.save();
          } else {
            return res.status(403).json({ success: false, error: 'Account is suspended' });
          }
        }

        if (!user.securePinHash || !verifyPin(pin, user.securePinHash)) {
          return res.status(400).json({ success: false, error: 'Invalid backup PIN' });
        }

        const now = new Date();
        if (deviceId) {
          await TrustedDevice.findOneAndUpdate(
            { userEmail: cleanEmail, deviceId },
            {
              userEmail: cleanEmail,
              deviceId,
              deviceName: deviceName || 'Unknown Device',
              platform: platform || 'unknown',
              lastLoginDate: now,
              isActive: true,
              $setOnInsert: { firstLoginDate: now },
            },
            { upsert: true, new: true }
          );
        }

        const token = generateToken(user);
        return res.json({ success: true, token, user: getUserFromRecord(user) });
      }

      // 14. savePhoneNumber
      case 'savePhoneNumber': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { phoneNumber } = req.body;
        if (!phoneNumber) return res.status(400).json({ success: false, error: 'Phone number is required' });

        user.phoneNumber = phoneNumber;
        await user.save();

        return res.json({ success: true, user: getUserFromRecord(user) });
      }

      // 15. verifyAndUpdateEmail
      case 'verifyAndUpdateEmail': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { newEmail, code } = req.body;
        if (!newEmail || !code) return res.status(400).json({ success: false, error: 'New email and code are required' });

        const cleanNewEmail = newEmail.toLowerCase().trim();
        const codes = await VerificationCode.find({ email: cleanNewEmail, type: 'changeEmail', used: false }).sort({ createdAt: -1 });
        if (!codes || codes.length === 0) {
          return res.status(400).json({ success: false, error: 'No active verification code' });
        }

        const matchingCode = codes.find(c => c.code === code);
        if (!matchingCode) {
          return res.status(400).json({ success: false, error: 'Invalid verification code' });
        }

        if (new Date(matchingCode.expiresAt) < new Date()) {
          matchingCode.used = true;
          await matchingCode.save();
          return res.status(400).json({ success: false, error: 'Code has expired' });
        }

        matchingCode.used = true;
        await matchingCode.save();

        const existing = await KoraUser.findOne({ email: cleanNewEmail });
        if (existing && existing._id.toString() !== user._id.toString()) {
          return res.status(400).json({ success: false, error: 'An account with this email already exists' });
        }

        user.email = cleanNewEmail;
        await user.save();

        return res.json({ success: true, user: getUserFromRecord(user) });
      }

      // 16. setPasskeysEnabled
      case 'setPasskeysEnabled': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { enabled } = req.body;
        user.passkeysEnabled = !!enabled;
        await user.save();

        return res.json({ success: true, passkeysEnabled: !!enabled });
      }

      // 17. createPasskey
      case 'createPasskey': {
        const user = await authenticateRequest(req);
        if (!user) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const { deviceId, deviceName, platform, publicKey, signingKey } = req.body;
        if (!deviceId) return res.status(400).json({ success: false, error: 'Device ID is required' });

        let passkey = await Passkey.findOne({ userEmail: user.email, deviceId });
        if (passkey) {
          if (deviceName) passkey.deviceName = deviceName;
          if (platform) passkey.platform = platform;
          if (publicKey) passkey.publicKey = publicKey;
          if (signingKey) passkey.signingKey = signingKey;
          await passkey.save();
        } else {
          passkey = await Passkey.create({
            userEmail: user.email,
            deviceId,
            deviceName: deviceName || 'Unknown Device',
            platform: platform || 'unknown',
            publicKey,
            signingKey,
          });
        }

        user.passkeysEnabled = true;
        await user.save();

        return res.json({
          success: true,
          passkey: {
            id: passkey._id.toString(),
            deviceId: passkey.deviceId,
            deviceName: passkey.deviceName,
            platform: passkey.platform,
            createdAt: passkey.createdAt,
          },
        });
      }

      // 18. listPasskeys
      case 'listPasskeys': {
        const user = await authenticateRequest(req);
        const email = user ? user.email : (req.body.email ? req.body.email.toLowerCase().trim() : null);

        if (!email) return res.status(401).json({ success: false, error: 'Unauthorized' });

        const passkeys = await Passkey.find({ userEmail: email });
        const list = passkeys.map(p => ({
          id: p._id.toString(),
          deviceId: p.deviceId,
          deviceName: p.deviceName,
          platform: p.platform,
          createdAt: p.createdAt,
        }));

        return res.json({ success: true, passkeys: list });
      }

      // 19. deletePasskey
      case 'deletePasskey': {
        const user = await authenticateRequest(req);
        const email = user ? user.email : (req.body.email ? req.body.email.toLowerCase().trim() : null);
        const { passkeyId } = req.body;

        if (!email) return res.status(401).json({ success: false, error: 'Unauthorized' });
        if (!passkeyId) return res.status(400).json({ success: false, error: 'Passkey ID is required' });

        await Passkey.deleteOne({ _id: passkeyId, userEmail: email });

        const remaining = await Passkey.countDocuments({ userEmail: email });
        if (remaining === 0) {
          await KoraUser.updateOne({ email }, { $set: { passkeysEnabled: false } });
        }

        return res.json({ success: true, message: 'Passkey deleted' });
      }

      // 20. loginWithPasskey
      case 'loginWithPasskey': {
        const { email, deviceId, challenge, signature } = req.body;
        if (!email || !deviceId) return res.status(400).json({ success: false, error: 'Email and deviceId are required' });

        const cleanEmail = email.toLowerCase().trim();
        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) return res.status(404).json({ success: false, error: 'Account not found' });

        if (user.isSuspended) {
          if (user.suspensionExpiresAt && new Date(user.suspensionExpiresAt) < new Date()) {
            user.isSuspended = false;
            await user.save();
          } else {
            return res.status(403).json({ success: false, error: 'Account is suspended' });
          }
        }

        if (!user.passkeysEnabled) {
          return res.status(400).json({ success: false, error: 'Passkeys are not enabled for this account' });
        }

        const passkey = await Passkey.findOne({ userEmail: cleanEmail, deviceId });
        if (!passkey) {
          return res.status(400).json({ success: false, error: 'No passkey found for this device' });
        }

        const now = new Date();
        await TrustedDevice.findOneAndUpdate(
          { userEmail: cleanEmail, deviceId },
          {
            userEmail: cleanEmail,
            deviceId,
            deviceName: passkey.deviceName || 'Passkey Device',
            platform: passkey.platform || 'unknown',
            lastLoginDate: now,
            isActive: true,
            $setOnInsert: { firstLoginDate: now },
          },
          { upsert: true, new: true }
        );

        const token = generateToken(user);
        return res.json({ success: true, token, user: getUserFromRecord(user) });
      }

      // 21. checkSignInOptions
      case 'checkSignInOptions': {
        const { email } = req.body;
        if (!email) return res.status(400).json({ success: false, error: 'Email is required' });

        const cleanEmail = email.toLowerCase().trim();
        const user = await KoraUser.findOne({ email: cleanEmail });
        if (!user) {
          return res.json({ success: true, hasBackupPin: false, passkeysEnabled: false });
        }

        return res.json({
          success: true,
          hasBackupPin: !!user.securePinHash,
          passkeysEnabled: !!user.passkeysEnabled,
        });
      }

      // 22. logout
      case 'logout': {
        const user = await authenticateRequest(req);
        const { deviceId } = req.body;

        if (user && deviceId) {
          await TrustedDevice.updateOne(
            { userEmail: user.email, deviceId },
            { $set: { isActive: false } }
          );
        }

        return res.json({ success: true, message: 'Logged out successfully' });
      }

      // 23. checkPhoneNumbers
      case 'checkPhoneNumbers': {
        const { phoneNumbers } = req.body;
        if (!Array.isArray(phoneNumbers)) {
          return res.status(400).json({ success: false, error: 'phoneNumbers array is required' });
        }

        const users = await KoraUser.find({ phoneNumber: { $in: phoneNumbers } });
        const matches = users.map(u => ({
          phoneNumber: u.phoneNumber,
          koraId: u.koraId,
          username: u.username,
          fullName: u.fullName,
          avatarUrl: u.avatarUrl,
        }));

        const registeredNumbers = users.map(u => u.phoneNumber).filter(Boolean);

        return res.json({ success: true, matches, registeredNumbers });
      }

      // 24. checkPhoneNumber
      case 'checkPhoneNumber': {
        const { phoneNumber } = req.body;
        if (!phoneNumber) return res.status(400).json({ success: false, error: 'Phone number is required' });

        const user = await KoraUser.findOne({ phoneNumber });
        if (user) {
          return res.json({
            success: true,
            exists: true,
            available: false,
            user: {
              koraId: user.koraId,
              username: user.username,
              fullName: user.fullName,
              avatarUrl: user.avatarUrl,
            },
          });
        }

        return res.json({ success: true, exists: false, available: true, user: null });
      }

      // 25. checkKoraId
      case 'checkKoraId': {
        const { koraId } = req.body;
        if (!koraId) return res.status(400).json({ success: false, error: 'Kora ID is required' });

        const existing = await KoraUser.findOne({ koraId: koraId.trim() });
        return res.json({ success: true, available: !existing });
      }

      // 26. recoverSubscription
      case 'recoverSubscription': {
        const { email } = req.body;
        let user = null;
        if (email) {
          user = await KoraUser.findOne({ email: email.toLowerCase().trim() });
        } else {
          user = await authenticateRequest(req);
        }

        if (!user) return res.status(404).json({ success: false, error: 'User not found' });

        const isPremium = computeIsPremium(user);
        return res.json({
          success: true,
          isPremium,
          premiumExpiresAt: user.premiumExpiresAt,
          premiumSource: user.premiumSource,
          user: getUserFromRecord(user),
        });
      }

      // 27. lookupUser
      case 'lookupUser': {
        const { query } = req.body;
        if (!query) return res.status(400).json({ success: false, error: 'Query is required' });

        const cleanQuery = query.toLowerCase().trim();
        const users = await KoraUser.find({
          $or: [
            { email: cleanQuery },
            { koraId: cleanQuery },
            { username: cleanQuery },
            { fullName: { $regex: cleanQuery, $options: 'i' } },
          ],
        }).limit(20);

        const formattedUsers = users.map(u => getUserFromRecord(u));
        return res.json({ success: true, users: formattedUsers });
      }

      default:
        return res.status(400).json({ success: false, error: `Unknown action: ${action}` });
    }
  } catch (error) {
    console.error(`[Auth Route Error] Action '${req.body?.action}':`, error);
    return res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

export default router;
