const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const User = require('../models/User');
const VerificationCode = require('../models/VerificationCode');
const { sendVerificationCode, sendSecurityAlertEmail } = require('../mailer');

const router = express.Router();

// Same reserved list as the app (lib/services/auth_service.dart) — the
// backend enforces it too so reserved names can never be claimed via API.
const RESERVED_USERNAMES = new Set([
  'admin','administrator','kora','koramessenger','koraofficial','support','help',
  'system','root','official','team','staff','moderator','mod','settings','about',
  'security','login','register','signup','api','bot','null','undefined','test',
  'demo','info','contact','welcome','home','messenger','founder','ceo','dev',
  'developer','operator','service','page','profile','account','user','me','my',
  'all','new','edit','delete','create','post','message','chat','group','channel',
  'broadcast','notification','verify','auth',
]);

const CODE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const MAX_ATTEMPTS = 5;

function ok(res, extra = {}) {
  return res.json({ success: true, ...extra });
}
function fail(res, error, status = 200) {
  // The app parses the JSON body even on non-200, and treats missing
  // 'success' as failure — keep errors in the body either way.
  return res.status(status).json({ success: false, error });
}

function generateKoraId() {
  const n = crypto.randomInt(100000000, 1000000000);
  return `KM-${n}`;
}

function generateCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

const USERNAME_RE = /^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$/;

function validateUsername(username) {
  if (!username) return 'Username is required';
  if (username.length < 3) return 'Must be at least 3 characters';
  if (username.length > 20) return 'Must be at most 20 characters';
  if (!/^[a-zA-Z]/.test(username)) return 'Must start with a letter';
  if (!/^[a-zA-Z0-9_]+$/.test(username)) return 'Only letters, numbers, and underscores';
  if (username.endsWith('_')) return 'Cannot end with an underscore';
  if (username.includes('__')) return 'No consecutive underscores';
  if (RESERVED_USERNAMES.has(username.toLowerCase())) {
    return 'This username is reserved';
  }
  return null;
}

/// Issues a fresh 6-digit code for email+type, invalidating older ones.
async function issueCode(email, type) {
  await VerificationCode.updateMany(
    { email, type, used: false },
    { $set: { used: true } }
  );
  const code = generateCode();
  await VerificationCode.create({
    email,
    code,
    type,
    expiresAt: new Date(Date.now() + CODE_TTL_MS),
  });
  await sendVerificationCode(email, code, type);
  // TEST-ONLY: lets the auth test suite read codes without SMTP.
  // Controlled by env var; must stay unset in production.
  if (process.env.DEV_RETURN_CODES === 'true') {
    lastDevCode = { email, code, type, at: Date.now() };
  }
}

let lastDevCode = null;

// ── shared helpers for the account/security actions ────────────
function clientIp(req) {
  return (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.headers['x-real-ip']
    || req.headers['cf-connecting-ip']
    || 'Unknown';
}

function eventTimestamp() {
  return new Date().toLocaleString('en-US', {
    timeZone: 'UTC',
    dateStyle: 'full',
    timeStyle: 'short',
  });
}

/// Fire-and-forget security alert email — never blocks the response.
function fireSecurityAlert(req, email, deviceName, action, deviceId) {
  sendSecurityAlertEmail(
    email,
    deviceName || 'Unknown Device',
    action,
    eventTimestamp(),
    deviceId,
    clientIp(req)
  ).catch((e) => console.error(`[koraAuth] security alert failed: ${e.message}`));
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function normalizeDigits(p) {
  return String(p || '').replace(/\D/g, '');
}

/// Register/refresh a device on the account (pin/passkey logins).
function upsertDevice(user, deviceId, deviceName, platform) {
  const now = new Date();
  const existing = user.devices.find((d) => d.deviceId === deviceId);
  if (existing) {
    existing.lastLoginDate = now;
    existing.isActive = true;
  } else if (deviceName) {
    user.devices.push({
      deviceId,
      deviceName: String(deviceName),
      platform: platform || 'unknown',
      firstLoginDate: now,
      lastLoginDate: now,
      isActive: true,
      isTrusted: false,
    });
  }
}

/// Phone match: exact, without +, then last-10-digits (country-code formats).
async function findUserByPhone(normalized) {
  let user = await User.findOne({ phoneNumber: normalized });
  if (!user) user = await User.findOne({ phoneNumber: normalized.replace(/^\+/, '') });
  if (!user) {
    const last10 = normalizeDigits(normalized).slice(-10);
    if (last10.length >= 9) {
      const candidates = await User.find({}).select('phoneNumber');
      const match = candidates.find((u) => {
        const digits = normalizeDigits(u.phoneNumber);
        return digits.length >= 9 && digits.slice(-10) === last10;
      });
      if (match) user = await User.findById(match._id);
    }
  }
  return user;
}

function passkeyClient(p) {
  return {
    id: p.keyId,
    deviceName: p.deviceName,
    platform: p.platform,
    createdAt: p.createdAt ? p.createdAt.toISOString() : null,
  };
}

/// Verifies a code; returns null on success or an error string.
async function checkCode(email, code, type) {
  const record = await VerificationCode.findOne({ email, type, used: false }).sort({ createdAt: -1 });
  if (!record) return 'No verification code found. Please request a new one.';
  if (record.expiresAt < new Date()) return 'This code has expired. Please request a new one.';
  if (record.attempts >= MAX_ATTEMPTS) {
    return 'Too many incorrect attempts. Please request a new code.';
  }
  if (record.code !== String(code)) {
    record.attempts += 1;
    await record.save();
    const left = MAX_ATTEMPTS - record.attempts;
    return left > 0
      ? `Incorrect code. ${left} attempt${left === 1 ? '' : 's'} left.`
      : 'Too many incorrect attempts. Please request a new code.';
  }
  record.used = true;
  await record.save();
  return null;
}

router.post('/', async (req, res) => {
  const { action } = req.body || {};
  try {
    switch (action) {
      case 'checkUsername': {
        const username = String(req.body.username || '').trim();
        const error = validateUsername(username);
        if (error) {
          if (username.length < 3) return fail(res, error);
          // Reserved is reported distinctly so the app shows the right status.
          if (RESERVED_USERNAMES.has(username.toLowerCase())) {
            return ok(res, { available: false, reason: 'This username is reserved' });
          }
          return fail(res, error);
        }
        const existing = await User.findOne({ username }).collation({ locale: 'en', strength: 2 });
        if (existing) return ok(res, { available: false, reason: 'Username is already taken' });
        return ok(res, { available: true });
      }

      case 'getDevCode': {
        // TEST-ONLY endpoint, gated behind DEV_RETURN_CODES=true.
        if (process.env.DEV_RETURN_CODES !== 'true') return fail(res, 'Not available');
        if (!lastDevCode) return fail(res, 'No code issued yet');
        return ok(res, lastDevCode);
      }

      case 'sendCode': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const type = req.body.type || 'registration';
        if (!email || !email.includes('@')) return fail(res, 'A valid email is required');
        if (type === 'registration') {
          const existing = await User.findOne({ email });
          if (existing) return fail(res, 'An account with this email already exists');
        }
        if (type === 'passwordReset') {
          const existing = await User.findOne({ email });
          if (!existing) return fail(res, 'No account found with this email');
        }
        await issueCode(email, type);
        return ok(res);
      }

      case 'resendCode': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const type = req.body.type || 'login';
        await issueCode(email, type);
        // Telegram-style delivery chain: for now email is the only
        // method, so deliveryMethod='email' with no further fallback.
        return ok(res, {
          deliveryMethod: 'email',
          nextType: null,
          timeout: 30,
        });
      }

      case 'verifyCode': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const error = await checkCode(email, req.body.code, req.body.type || 'login');
        if (error) return fail(res, error);
        return ok(res);
      }

      case 'verifyAndSignUp': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const code = req.body.userData && req.body.userData.password
          ? req.body.code
          : req.body.code;
        const codeError = await checkCode(email, code, 'registration');
        if (codeError) return fail(res, codeError);

        const ud = req.body.userData || {};
        const password = String(ud.password || '');
        if (password.length < 8) return fail(res, 'Password must be at least 8 characters');

        const username = String(ud.username || '').trim();
        const usernameError = validateUsername(username);
        if (usernameError) return fail(res, usernameError);
        const taken = await User.findOne({ username }).collation({ locale: 'en', strength: 2 });
        if (taken) return fail(res, 'Username is already taken');

        const existing = await User.findOne({ email });
        if (existing) return fail(res, 'An account with this email already exists');

        const user = await User.create({
          email,
          passwordHash: await bcrypt.hash(password, 10),
          fullName: ud.fullName || '',
          username,
          koraId: generateKoraId(),
          bio: ud.bio || '',
          avatarUrl: ud.avatarUrl || '',
          profileCompleted: Boolean(ud.profileCompleted),
        });
        return ok(res, { user: user.toClient() });
      }

      case 'login': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const password = String(req.body.password || '');
        const deviceId = String(req.body.deviceId || '');
        const deviceName = String(req.body.deviceName || 'Unknown device');
        const platform = String(req.body.platform || 'unknown');

        const user = await User.findOne({ email });
        if (!user || !user.passwordHash) return fail(res, 'Invalid email or password');
        if (user.isSuspended) return fail(res, 'This account is currently suspended');

        const match = await bcrypt.compare(password, user.passwordHash);
        if (!match) return fail(res, 'Invalid email or password');

        // Known device → straight in. New device → email verification.
        const known = user.devices.find((d) => d.deviceId === deviceId && d.isActive);
        if (known) {
          known.lastLoginDate = new Date();
          await user.save();
          return ok(res, { user: user.toClient() });
        }

        await issueCode(email, 'login');
        return res.json({
          success: false,
          needsDeviceVerification: true,
          deliveryMethod: 'email',
          nextType: null,
          timeout: 30,
        });
      }

      case 'verifyLogin': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const code = req.body.code;
        const deviceId = String(req.body.deviceId || '');
        const deviceName = String(req.body.deviceName || 'Unknown device');
        const platform = String(req.body.platform || 'unknown');
        const recognizeDevice = req.body.recognizeDevice !== false;

        const codeError = await checkCode(email, code, 'login');
        if (codeError) return fail(res, codeError);

        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Account not found');
        if (user.isSuspended) return fail(res, 'This account is currently suspended');

        if (recognizeDevice && deviceId) {
          const existing = user.devices.find((d) => d.deviceId === deviceId);
          if (existing) {
            existing.lastLoginDate = new Date();
            existing.isActive = true;
          } else {
            user.devices.push({
              deviceId,
              deviceName,
              platform,
              firstLoginDate: new Date(),
              lastLoginDate: new Date(),
              isTrusted: true,
              isActive: true,
            });
          }
          await user.save();
        }
        return ok(res, { user: user.toClient() });
      }

      case 'verifyAndResetPassword': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const codeError = await checkCode(email, req.body.code, 'passwordReset');
        if (codeError) return fail(res, codeError);
        const newPassword = String(req.body.newPassword || '');
        if (newPassword.length < 8) return fail(res, 'Password must be at least 8 characters');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Account not found');
        user.passwordHash = await bcrypt.hash(newPassword, 10);
        // Security: force all other devices to re-verify after a reset.
        user.devices = user.devices.filter((d) => d.deviceId === req.body.deviceId);
        await user.save();
        return ok(res);
      }

      case 'saveProfile': {
        const userId = req.body.userId;
        const user = await User.findById(userId);
        if (!user) return fail(res, 'Account not found');
        if (req.body.fullName !== undefined) user.fullName = String(req.body.fullName);
        if (req.body.username !== undefined && req.body.username) {
          const username = String(req.body.username).trim();
          const usernameError = validateUsername(username);
          if (usernameError) return fail(res, usernameError);
          const taken = await User.findOne({
            username,
            _id: { $ne: user._id },
          }).collation({ locale: 'en', strength: 2 });
          if (taken) return fail(res, 'Username is already taken');
          user.username = username;
        }
        if (req.body.bio !== undefined) user.bio = String(req.body.bio);
        if (req.body.avatarUrl !== undefined) user.avatarUrl = String(req.body.avatarUrl);
        user.profileCompleted = true;
        await user.save();
        return ok(res, { user: user.toClient() });
      }

      case 'getProfile': {
        const user = await User.findById(req.body.userId);
        if (!user) return fail(res, 'Account not found');
        return ok(res, { user: user.toClient() });
      }

      case 'checkSignInOptions': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const user = await User.findOne({ email });
        if (!user) return ok(res, { hasBackupPin: false, passkeysEnabled: false });
        return ok(res, {
          hasBackupPin: Boolean(user.securePinHash),
          passkeysEnabled: Boolean(user.passkeysEnabled),
        });
      }

      // ── REQUEST ACCOUNT INFO ────────────────────────────────
      case 'requestAccountInfo': {
        const userId = req.body.userId;
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!userId || !email) return fail(res, 'User ID and email are required');
        const user = await User.findById(userId);
        if (!user) return fail(res, 'Account not found');
        return ok(res, {
          accountCreated: user.createdAt ? user.createdAt.toISOString() : null,
          deviceCount: user.devices.filter((d) => d.isActive).length,
          profile: {
            fullName: user.fullName,
            username: user.username || '',
            koraId: user.koraId,
            email: user.email,
            bio: user.bio || '',
            avatarUrl: user.avatarUrl || '',
            isVerified: user.isVerified,
            profileCompleted: user.profileCompleted,
          },
        });
      }

      // ── DELETE ACCOUNT ──────────────────────────────────────
      case 'deleteAccount': {
        const userId = req.body.userId;
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!userId || !email) return fail(res, 'User ID and email are required');
        const user = await User.findById(userId);
        if (!user) return fail(res, 'Account not found');
        await VerificationCode.deleteMany({ email: user.email });
        await user.deleteOne();
        return ok(res, { message: 'Account deleted successfully' });
      }

      // ── SAVE BACKUP PIN ─────────────────────────────────────
      case 'saveBackupPin': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const pin = req.body.pin;
        if (!email || !pin) return fail(res, 'Email and PIN are required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Account not found');
        user.securePinHash = sha256(pin);
        await user.save();
        return ok(res, { message: 'Backup PIN saved' });
      }

      // ── LOGIN WITH BACKUP PIN ───────────────────────────────
      case 'loginWithBackupPin': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const pin = String(req.body.pin || '');
        const deviceId = String(req.body.deviceId || '');
        if (!email || !pin) return fail(res, 'Email and PIN are required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Invalid email or PIN');
        if (!user.securePinHash) {
          return fail(res, 'No backup PIN set. Please use email and password to log in.');
        }
        if (sha256(pin) !== user.securePinHash) return fail(res, 'Invalid backup PIN');
        if (deviceId) upsertDevice(user, deviceId, req.body.deviceName, req.body.platform);
        await user.save();
        fireSecurityAlert(req, email, req.body.deviceName, 'Account Login', deviceId);
        return ok(res, { user: user.toClient() });
      }

      // ── SAVE PHONE NUMBER (onboarding) ──────────────────────
      case 'savePhoneNumber': {
        const user = await User.findById(req.body.userId);
        if (!user) return fail(res, 'User ID is required');
        user.phoneNumber = String(req.body.phoneNumber || '');
        await user.save();
        return ok(res, { user: user.toClient() });
      }

      // ── VERIFY AND UPDATE EMAIL ──────────────────────────────
      case 'verifyAndUpdateEmail': {
        const userId = req.body.userId;
        const newEmail = String(req.body.newEmail || '').toLowerCase().trim();
        const code = req.body.code;
        if (!userId || !newEmail || !code) {
          return fail(res, 'User ID, new email, and code are required');
        }
        const codeError = await checkCode(newEmail, code, 'changeEmail');
        if (codeError) return fail(res, codeError);
        const taken = await User.findOne({ email: newEmail, _id: { $ne: userId } });
        if (taken) return fail(res, 'An account with this email already exists');
        const user = await User.findById(userId);
        if (!user) return fail(res, 'Account not found');
        user.email = newEmail;
        await user.save();
        return ok(res, { user: user.toClient() });
      }

      // ── SET PASSKEYS ENABLED ─────────────────────────────────
      case 'setPasskeysEnabled': {
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!email) return fail(res, 'Email is required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Account not found');
        user.passkeysEnabled = Boolean(req.body.enabled);
        await user.save();
        return ok(res);
      }

      // ── CREATE PASSKEY ───────────────────────────────────────
      case 'createPasskey': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const deviceId = String(req.body.deviceId || '');
        if (!email || !deviceId) return fail(res, 'Email and device ID are required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Account not found');
        const existing = user.passkeys.find((p) => p.deviceId === deviceId);
        if (existing) {
          if (req.body.deviceName) existing.deviceName = String(req.body.deviceName);
          if (req.body.platform) existing.platform = String(req.body.platform);
          await user.save();
          return ok(res, { passkey: passkeyClient(existing) });
        }
        user.passkeys.push({
          keyId: crypto.randomUUID(),
          deviceId,
          deviceName: String(req.body.deviceName || 'Unknown Device'),
          platform: String(req.body.platform || 'unknown'),
          createdAt: new Date(),
        });
        user.passkeysEnabled = true;
        await user.save();
        return ok(res, { passkey: passkeyClient(user.passkeys.find((p) => p.deviceId === deviceId)) });
      }

      // ── LIST PASSKEYS ────────────────────────────────────────
      case 'listPasskeys': {
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!email) return fail(res, 'Email is required');
        const user = await User.findOne({ email });
        return ok(res, { passkeys: (user ? user.passkeys : []).map(passkeyClient) });
      }

      // ── DELETE PASSKEY ───────────────────────────────────────
      case 'deletePasskey': {
        const passkeyId = String(req.body.passkeyId || '');
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!passkeyId || !email) return fail(res, 'Passkey ID and email are required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Passkey not found');
        const match = user.passkeys.find((p) => p.keyId === passkeyId);
        if (!match) return fail(res, 'Passkey not found');
        user.passkeys = user.passkeys.filter((p) => p.keyId !== passkeyId);
        if (user.passkeys.length === 0) user.passkeysEnabled = false;
        await user.save();
        return ok(res, { message: 'Passkey deleted' });
      }

      // ── LOGIN WITH PASSKEY ───────────────────────────────────
      case 'loginWithPasskey': {
        const email = String(req.body.email || '').toLowerCase().trim();
        const deviceId = String(req.body.deviceId || '');
        if (!email || !deviceId) return fail(res, 'Email and device ID are required');
        const user = await User.findOne({ email });
        if (!user) return fail(res, 'Invalid email');
        if (!user.passkeysEnabled) return fail(res, 'Passkeys are not enabled for this account');
        if (!user.passkeys.some((p) => p.deviceId === deviceId)) {
          return fail(res, 'No passkey found for this device');
        }
        upsertDevice(user, deviceId, req.body.deviceName, req.body.platform);
        await user.save();
        fireSecurityAlert(req, email, req.body.deviceName, 'Account Login', deviceId);
        return ok(res, { user: user.toClient() });
      }

      // ── LOGOUT (security email) ─────────────────────────────
      case 'logout': {
        const email = String(req.body.email || '').toLowerCase().trim();
        if (!email) return fail(res, 'Email is required');
        fireSecurityAlert(req, email, req.body.deviceName, 'Account Logout', req.body.deviceId);
        return ok(res, { message: 'Logout successful' });
      }

      // ── CHECK PHONE NUMBERS IN BULK (contact sync) ───────────
      case 'checkPhoneNumbers': {
        const phoneNumbers = req.body.phoneNumbers;
        if (!Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
          return fail(res, 'phoneNumbers array is required');
        }
        const allUsers = await User.find({});
        const byLast10 = new Map();
        for (const u of allUsers) {
          const digits = normalizeDigits(u.phoneNumber);
          if (digits.length >= 9) byLast10.set(digits.slice(-10), u);
        }
        const results = {};
        for (const phoneNumber of phoneNumbers) {
          const last10 = normalizeDigits(phoneNumber).slice(-10);
          const match = last10.length >= 9 ? byLast10.get(last10) : undefined;
          results[phoneNumber] = match
            ? { registered: true, user: match.toClient() }
            : { registered: false };
        }
        return ok(res, { results });
      }

      // ── CHECK PHONE NUMBER (registered on Kora?) ──────────────
      case 'checkPhoneNumber': {
        const raw = String(req.body.phoneNumber || '');
        if (!raw) return fail(res, 'Phone number is required');
        let normalized = raw.replace(/\s+/g, '');
        if (!normalized.startsWith('+') && !normalized.startsWith('0')) {
          normalized = '+' + normalized;
        }
        const user = await findUserByPhone(normalized);
        if (!user) return ok(res, { registered: false });
        return ok(res, { registered: true, user: user.toClient() });
      }

      // ── CHECK KORA ID ─────────────────────────────────────────
      case 'checkKoraId': {
        const koraId = String(req.body.koraId || '');
        if (!koraId) return fail(res, 'Kora ID is required');
        const user = await User.findOne({ koraId });
        if (!user) return ok(res, { registered: false });
        return ok(res, { registered: true, user: user.toClient() });
      }

      // ── RECOVER SUBSCRIPTION (premium restore) ────────────────
      case 'recoverSubscription': {
        let user = null;
        if (req.body.userId) user = await User.findById(req.body.userId);
        if (!user && req.body.email) {
          user = await User.findOne({ email: String(req.body.email).toLowerCase().trim() });
        }
        if (!user) return fail(res, 'Account not found');
        return ok(res, {
          isPremium: User.computeIsPremium(user),
          premiumExpiresAt: user.premiumExpiresAt ? new Date(user.premiumExpiresAt).toISOString() : null,
          premiumSource: user.premiumSource || '',
          user: user.toClient(),
        });
      }

      // ── LOOKUP USER (by username or koraId) ───────────────────
      case 'lookupUser': {
        const identifier = String(req.body.identifier || '').trim();
        if (!identifier) return fail(res, 'Identifier is required');
        if (identifier.toUpperCase().startsWith('KM-')) {
          const user = await User.findOne({ koraId: identifier.toUpperCase() });
          return user
            ? ok(res, { found: true, type: 'koraId', user: user.toClient() })
            : ok(res, { found: false, type: 'koraId' });
        }
        const username = identifier.startsWith('@') ? identifier.substring(1) : identifier;
        const user = await User.findOne({ username }).collation({ locale: 'en', strength: 2 });
        return user
          ? ok(res, { found: true, type: 'username', user: user.toClient() })
          : ok(res, { found: false, type: 'username' });
      }

      default:
        return fail(res, `Unknown action: ${action}`, 400);
    }
  } catch (err) {
    console.error(`[koraAuth] action=${action} error:`, err);
    return fail(res, 'Internal server error. Please try again.', 500);
  }
});

module.exports = router;
