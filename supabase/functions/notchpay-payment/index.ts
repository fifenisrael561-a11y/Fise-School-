import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "Authentication required." }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("NOTCHPAY_PUBLIC_KEY");
    if (!supabaseUrl || !serviceKey || !publicKey) {
      throw new Error("Supabase/Notch Pay secrets are not configured.");
    }

    const token = authHeader.substring("Bearer ".length);
    const admin = createClient(supabaseUrl, serviceKey);
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "Invalid session." }, 401);

    const body = await req.json();
    const amount = Number(body?.amount ?? 1000);
    const currency = String(body?.currency ?? "XAF").toUpperCase();
    if (amount !== 1000 || currency !== "XAF") {
      return json({ error: "Fise School Premium must be 1000 XAF." }, 400);
    }

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("first_name,last_name,email,phone")
      .eq("id", authData.user.id)
      .single();
    if (profileError) throw profileError;

    const teacherCode = String(body?.teacher_code ?? "").trim();
    let teacherId: string | null = null;
    if (teacherCode) {
      const { data: resolved, error: resolveError } = await admin.rpc(
        "resolve_teacher_payment_code",
        { p_code: teacherCode },
      );
      if (resolveError || !resolved) return json({ error: "Invalid teacher code." }, 400);
      teacherId = String(resolved);
    }

    const reference = `FISE-${Date.now()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
    const callback = `${supabaseUrl}/functions/v1/notchpay-callback`;
    const email = String(body?.email ?? profile.email ?? authData.user.email ?? "").trim();
    const phone = String(profile.phone ?? authData.user.phone ?? "").trim();
    const name = String(body?.name ?? `${profile.first_name ?? ""} ${profile.last_name ?? ""}`).trim();

    const paymentResponse = await fetch("https://api.notchpay.co/payments", {
      method: "POST",
      headers: {
        "Authorization": publicKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount,
        currency,
        customer: {
          name: name || "Fise School Student",
          ...(email ? { email } : {}),
          ...(phone ? { phone } : {}),
        },
        description: String(body?.description ?? "Abonnement Fise School"),
        reference,
        callback,
      }),
    });

    const paymentData = await paymentResponse.json();
    if (!paymentResponse.ok) {
      throw new Error(paymentData?.message ?? paymentData?.error?.message ?? "Notch Pay payment initialization failed.");
    }

    const authorizationUrl = paymentData?.authorization_url ?? paymentData?.transaction?.authorization_url;
    const returnedReference = String(paymentData?.reference ?? paymentData?.transaction?.reference ?? reference);
    const providerTransactionId = paymentData?.transaction?.id ?? null;
    if (!authorizationUrl) throw new Error("Notch Pay returned no authorization URL.");

    const { error: insertError } = await admin.from("payment_orders").insert({
      user_id: authData.user.id,
      reference: returnedReference,
      amount,
      currency,
      status: "PENDING",
      description: String(body?.description ?? "Abonnement Fise School"),
      provider: "notchpay",
      provider_transaction_id: providerTransactionId,
      teacher_id: teacherId,
      teacher_commission_xaf: teacherId ? 200 : 0,
      platform_revenue_xaf: teacherId ? 800 : 1000,
    });
    if (insertError) throw insertError;

    return json({
      authorization_url: authorizationUrl,
      reference: returnedReference,
      teacher_id: teacherId,
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
