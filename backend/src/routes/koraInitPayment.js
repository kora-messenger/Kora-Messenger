const express = require('express');

const router = express.Router();

/**
 * Kora Payment — Initialize Paystack Transaction
 *
 * Called by the Flutter app when a user taps "Subscribe".
 * Uses the Paystack secret key (server-side only — never exposed to the frontend)
 * to initialize a transaction and return the hosted checkout URL.
 *
 * Environment variables:
 *   - PAYSTACK_SECRET_KEY — sk_test_... or sk_live_...
 *
 * Paystack API: POST https://api.paystack.co/transaction/initialize
 */

router.post('/', async (req, res) => {
  try {
    const { email, amount, currency, plan, planName } = req.body || {};

    const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

    if (!PAYSTACK_SECRET_KEY) {
      return res.status(500).json({ error: "Payment service not configured." });
    }

    if (!email || !amount) {
      return res.status(400).json({ error: "Email and amount are required." });
    }

    // Paystack expects amounts in the smallest currency unit (kobo for NGN, cents for USD)
    const amountInSmallestUnit = Math.round(parseFloat(amount) * 100);

    // Generate a unique reference
    const reference = `kora-${plan}-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;

    const response = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: email,
        amount: amountInSmallestUnit,
        currency: currency || "NGN",
        reference: reference,
        callback_url: "kora://payment/callback",
        metadata: {
          custom_fields: [
            { display_name: "App", variable_name: "app", value: "Kora Messenger" },
            { display_name: "Plan", variable_name: "plan", value: planName || plan },
            { display_name: "Plan Type", variable_name: "plan_type", value: plan },
          ],
        },
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return res.status(400).json({ error: data.message || "Failed to initialize transaction." });
    }

    return res.status(200).json({
      success: true,
      authorization_url: data.data.authorization_url,
      reference: data.data.reference,
    });
  } catch (err) {
    return res.status(500).json({
      error: `Payment initialization failed: ${err.message || "Unknown error"}`,
    });
  }
});

module.exports = router;
