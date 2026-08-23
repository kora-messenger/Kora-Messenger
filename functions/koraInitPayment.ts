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

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { email, amount, currency, plan, planName } = body;

    const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY");

    if (!PAYSTACK_SECRET_KEY) {
      return new Response(
        JSON.stringify({ error: "Payment service not configured." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!email || !amount) {
      return new Response(
        JSON.stringify({ error: "Email and amount are required." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
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
      return new Response(
        JSON.stringify({ error: data.message || "Failed to initialize transaction." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        authorization_url: data.data.authorization_url,
        reference: data.data.reference,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Payment initialization failed: ${err.message || "Unknown error"}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
