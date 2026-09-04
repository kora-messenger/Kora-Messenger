const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const User = require('../models/User');
const VerificationCode = require('../models/VerificationCode');
const { sendVerificationCode } = require('../mailer');

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
        if (!user) return fail(res, 'No account found with this email');
        return ok(res, {
          hasBackupPin: Boolean(user.securePinHash),
          passkeysEnabled: Boolean(user.passkeysEnabled),
        });
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
