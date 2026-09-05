const express = require('express');
const User = require('../models/User');

const router = express.Router();

/**
 * Kora Payment — Verify Paystack Transaction
 *
 * Called by the Flutter app after the user completes the Paystack checkout.
 * Verifies the transaction server-side using the secret key.
 *
 * Environment variables:
 *   - PAYSTACK_SECRET_KEY — sk_test_... or sk_live_...
 *
 * Paystack API: GET https://api.paystack.co/transaction/verify/:reference
 */

router.post('/', async (req, res) => {
  try {
    const { reference, email } = req.body || {};

    const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

    if (!PAYSTACK_SECRET_KEY) {
      return res.status(500).json({ success: false, message: "Payment service not configured." });
    }

    if (!reference) {
      return res.status(400).json({ success: false, message: "Transaction reference is required." });
    }

    const response = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );

    const data = await response.json();

    if (!response.ok) {
      return res.status(400).json({ success: false, message: data.message || "Verification failed." });
    }

    const status = data.data?.status;
    const amount = data.data?.amount;
    const currencyData = data.data?.currency;
    const metadata = data.data?.metadata;

    // Determine plan type from metadata or reference
    let planType = "monthly";
    if (metadata?.custom_fields) {
      const planField = metadata.custom_fields.find(
        (f) => f.variable_name === "plan_type"
      );
      if (planField?.value) planType = planField.value;
    } else if (reference.includes("yearly")) {
      planType = "yearly";
    }

    if (status === "success") {
      // Write premium status to the database so the backend is always
      // the source of truth — enables subscription recovery across
      // reinstalls and device switches.
      if (email) {
        try {
          const lowerEmail = String(email).toLowerCase().trim();
          const user = await User.findOne({ email: lowerEmail });
          if (user) {
            const now = new Date();
            const durationDays = planType === "yearly" ? 365 : 30;
            const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
            user.isPremium = true;
            user.premiumExpiresAt = expiresAt;
            user.premiumSource = planType;
            await user.save();
          }
        } catch (dbErr) {
          // Don't fail the payment verification if the DB write fails —
          // the client-side activation still works as a fallback.
          console.error("Failed to write premium to DB:", dbErr);
        }
      }

      return res.status(200).json({
        success: true,
        planType: planType,
        reference: reference,
        amount: amount,
        currency: currencyData,
        message: "Payment verified successfully.",
      });
    } else {
      return res.status(400).json({ success: false, message: `Payment status: ${status}` });
    }
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: `Verification failed: ${err.message || "Unknown error"}`,
    });
  }
});

module.exports = router;
