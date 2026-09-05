const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');

const router = express.Router();

/**
 * Kora — Recover Subscription
 *
 * Re-checks a user's premium status from the database.
 * Used when a user reinstalls the app, switches devices, or had a
 * payment succeed but the local cache wasn't set (crash, etc).
 *
 * Accepts: { userId?, email? } — at least one is required.
 * Returns: { success, isPremium, premiumExpiresAt, premiumSource, user }
 */

function computeIsPremium(record) {
  const isPremium = record.isPremium ?? record.data?.isPremium ?? false;
  if (!isPremium) return false;
  const source = record.premiumSource ?? record.data?.premiumSource ?? '';
  if (source === 'owner_override') return true;
  const expiresAt = record.premiumExpiresAt ?? record.data?.premiumExpiresAt ?? null;
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() > Date.now();
}

function getUserFromRecord(record) {
  const isPremium = computeIsPremium(record);
  return {
    id: record._id ? record._id.toString() : (record.id || ''),
    email: record.email ?? record.data?.email ?? '',
    username: record.username ?? record.data?.username ?? '',
    koraId: record.koraId ?? record.data?.koraId ?? '',
    fullName: record.fullName ?? record.data?.fullName ?? '',
    bio: record.bio ?? record.data?.bio ?? '',
    avatarUrl: record.avatarUrl ?? record.data?.avatarUrl ?? '',
    isVerified: record.isVerified ?? record.data?.isVerified ?? true,
    profileCompleted: record.profileCompleted ?? record.data?.profileCompleted ?? false,
    phoneNumber: record.phoneNumber ?? record.data?.phoneNumber ?? '',
    isPremium: isPremium,
    premiumExpiresAt: record.premiumExpiresAt
      ? new Date(record.premiumExpiresAt).toISOString()
      : (record.data?.premiumExpiresAt ?? null),
    premiumSource: record.premiumSource ?? record.data?.premiumSource ?? '',
  };
}

router.post('/', async (req, res) => {
  try {
    const { userId, email } = req.body || {};

    if (!userId && !email) {
      return res.status(400).json({ success: false, error: 'User ID or email is required' });
    }

    let user = null;
    if (userId) {
      if (mongoose.Types.ObjectId.isValid(userId)) {
        user = await User.findById(userId);
      }
    }
    if (!user && email) {
      const lowerEmail = String(email).toLowerCase().trim();
      user = await User.findOne({ email: lowerEmail });
    }

    if (!user) {
      return res.status(404).json({ success: false, error: 'Account not found' });
    }

    const isPremium = computeIsPremium(user);
    const premiumExpiresAt = user.premiumExpiresAt
      ? new Date(user.premiumExpiresAt).toISOString()
      : (user.data?.premiumExpiresAt ?? null);
    const premiumSource = user.premiumSource ?? user.data?.premiumSource ?? '';

    return res.status(200).json({
      success: true,
      isPremium,
      premiumExpiresAt,
      premiumSource,
      user: getUserFromRecord(user),
    });
  } catch (e) {
    return res.status(500).json({
      success: false,
      error: e?.message || 'Internal server error',
    });
  }
});

module.exports = router;
