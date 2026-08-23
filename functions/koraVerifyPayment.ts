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

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { reference } = body;

    const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY");

    if (!PAYSTACK_SECRET_KEY) {
      return new Response(
        JSON.stringify({ success: false, message: "Payment service not configured." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!reference) {
      return new Response(
        JSON.stringify({ success: false, message: "Transaction reference is required." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
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
      return new Response(
        JSON.stringify({ success: false, message: data.message || "Verification failed." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
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
      return new Response(
        JSON.stringify({
          success: true,
          planType: planType,
          reference: reference,
          amount: amount,
          currency: currencyData,
          message: "Payment verified successfully.",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } else {
      return new Response(
        JSON.stringify({ success: false, message: `Payment status: ${status}` }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, message: `Verification failed: ${err.message || "Unknown error"}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
