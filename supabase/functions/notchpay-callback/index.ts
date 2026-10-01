import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const reference = url.searchParams.get("reference")?.trim();
    if (!reference) return new Response("Reference de paiement manquante.", { status: 400 });

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("NOTCHPAY_PUBLIC_KEY");
    if (!supabaseUrl || !serviceKey || !publicKey) return new Response("Payment configuration missing.", { status: 500 });

    const paymentResponse = await fetch(`https://api.notchpay.co/payments/${encodeURIComponent(reference)}`, {
      headers: { "Authorization": publicKey },
    });
    const paymentData = await paymentResponse.json();
    if (!paymentResponse.ok) return new Response("Impossible de vérifier le paiement.", { status: 502 });

    const status = String(paymentData?.transaction?.status ?? paymentData?.status ?? "").toLowerCase();
    if (status === "complete") {
      const admin = createClient(supabaseUrl, serviceKey);
      const providerId = paymentData?.transaction?.id ? String(paymentData.transaction.id) : null;
      const { error } = await admin.rpc("finalize_notchpay_payment", {
        p_reference: reference,
        p_provider_transaction_id: providerId,
      });
      if (error) return new Response(`Paiement confirmé mais finalisation impossible: ${error.message}`, { status: 500 });
      return new Response("Paiement confirmé. Vous pouvez revenir dans Fise School.", { status: 200 });
    }

    return new Response(`Paiement non finalisé (statut: ${status || "inconnu"}).`, { status: 200 });
  } catch (error) {
    return new Response(error instanceof Error ? error.message : "Erreur de paiement.", { status: 500 });
  }
});
