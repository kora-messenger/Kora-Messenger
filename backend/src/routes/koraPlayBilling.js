const express = require('express');
const { JWT } = require('google-auth-library');
const User = require('../models/User');

const router = express.Router();

const DEFAULT_PACKAGE_NAME = 'com.kora.messenger';

/**
 * Google Play Billing Verification Endpoint
 *
 * Actions:
 *   - "verifyPurchase": Verify a purchase token with Google Play Developer API (androidpublisher v3)
 *     Body: { action: "verifyPurchase", userEmail, purchaseToken, productId }
 */
router.post('/', async (req, res) => {
  const body = req.body || {};
  const action = body.action || 'verifyPurchase';
  const { userEmail, purchaseToken, productId } = body;

  if (action !== 'verifyPurchase') {
    return res.status(400).json({ success: false, error: `Unknown action: ${action}` });
  }

  if (!userEmail) {
    return res.status(400).json({ success: false, error: 'userEmail is required' });
  }

  if (!purchaseToken) {
    return res.status(400).json({ success: false, error: 'purchaseToken is required' });
  }

  const serviceAccountEnv = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountEnv) {
    return res.json({ success: false, error: 'Google Play Billing not configured' });
  }

  const lowerEmail = String(userEmail).toLowerCase().trim();
  const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME || DEFAULT_PACKAGE_NAME;

  let credentials;
  try {
    credentials = typeof serviceAccountEnv === 'string'
      ? JSON.parse(serviceAccountEnv)
      : serviceAccountEnv;
  } catch (err) {
    console.error('[koraPlayBilling] Failed to parse GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:', err.message);
    return res.json({ success: false, error: 'Invalid Google Play service account configuration' });
  }

  try {
    const authClient = new JWT({
      email: credentials.client_email,
      key: credentials.private_key,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    let isValid = false;
    let googleExpiryDate = null;

    // 1. Try Subscriptions v2 API
    try {
      const subV2Url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
      const subV2Res = await authClient.request({ url: subV2Url });

      if (subV2Res.status === 200 && subV2Res.data) {
        const state = subV2Res.data.subscriptionState;
        const lineItems = subV2Res.data.lineItems || [];
        const activeState = state === 'SUBSCRIPTION_STATE_ACTIVE' || state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';

        if (activeState) {
          isValid = true;
          const lineItem = lineItems[0] || {};
          if (lineItem.expiryTime) {
            googleExpiryDate = new Date(lineItem.expiryTime);
          } else if (subV2Res.data.latestInAppOwnershipItem?.expiryTime) {
            googleExpiryDate = new Date(subV2Res.data.latestInAppOwnershipItem.expiryTime);
          }
        }
      }
    } catch (v2Err) {
      console.log('[koraPlayBilling] Subscriptions v2 lookup failed or non-sub, trying product/v1:', v2Err.message);
    }

    // 2. Fallback to Subscriptions v1 API if needed
    if (!isValid && productId) {
      try {
        const subV1Url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
        const subV1Res = await authClient.request({ url: subV1Url });

        if (subV1Res.status === 200 && subV1Res.data) {
          const expiryMillis = Number(subV1Res.data.expiryTimeMillis);
          if (expiryMillis && expiryMillis > Date.now()) {
            isValid = true;
            googleExpiryDate = new Date(expiryMillis);
          }
        }
      } catch (v1Err) {
        console.log('[koraPlayBilling] Subscriptions v1 lookup failed:', v1Err.message);
      }
    }

    // 3. Fallback to One-Time Products API if needed
    if (!isValid && productId) {
      try {
        const prodUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
        const prodRes = await authClient.request({ url: prodUrl });

        if (prodRes.status === 200 && prodRes.data) {
          // purchaseState 0 = Purchased
          if (prodRes.data.purchaseState === 0) {
            isValid = true;
          }
        }
      } catch (prodErr) {
        console.log('[koraPlayBilling] One-time product lookup failed:', prodErr.message);
      }
    }

    if (!isValid) {
      return res.json({
        success: false,
        error: 'Google Play purchase verification failed or subscription expired',
      });
    }

    // Determine plan type and expiration duration
    const isYearly = productId ? productId.includes('yearly') || productId.includes('annual') : false;
    const planType = isYearly ? 'yearly' : 'monthly';
    const durationDays = isYearly ? 365 : 30;

    const expiresAt = googleExpiryDate || new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);

    // Update user in MongoDB
    const user = await User.findOne({ email: lowerEmail });
    if (user) {
      user.isPremium = true;
      user.premiumExpiresAt = expiresAt;
      user.premiumSource = 'google_play';
      await user.save();
    }

    return res.json({
      success: true,
      isPremium: true,
      planType,
      productId,
      premiumSource: 'google_play',
      premiumExpiresAt: expiresAt.toISOString(),
      message: 'Google Play purchase verified and premium activated.',
      user: user ? user.toClient() : null,
    });
  } catch (err) {
    console.error('[koraPlayBilling] Verification exception:', err);
    return res.status(500).json({
      success: false,
      error: `Google Play verification error: ${err.message || 'Unknown error'}`,
    });
  }
});

module.exports = router;
