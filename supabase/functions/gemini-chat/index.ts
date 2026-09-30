import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Authentication required." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY is not configured.");

    const body = await req.json();
    const message = String(body?.message ?? "").trim();
    const language = body?.language === "en" ? "en" : "fr";
    const profile = body?.profile ?? {};
    const image = body?.image;

    if (!message && !image?.base64) {
      throw new Error("A message or image is required.");
    }

    const schoolContext = language === "en"
      ? `You are Fise School AI, an educational assistant for Cameroon.
Student profile: subsystem=${profile.subsystem ?? "unknown"}, sector=${profile.sector ?? "unknown"},
class=${profile.className ?? "unknown"}, examLevel=${profile.examLevel ?? "unknown"}, exam=${profile.exam ?? "unknown"}.
Explain lessons, exercises and revision clearly and at the student's level.`
      : `Tu es l'assistant IA éducatif de Fise School au Cameroun.
Profil scolaire: sous-système=${profile.subsystem ?? "inconnu"}, secteur=${profile.sector ?? "inconnu"},
classe=${profile.className ?? "inconnue"}, niveau d'examen=${profile.examLevel ?? "inconnu"}, examen=${profile.exam ?? "inconnu"}.
Explique les leçons, exercices et révisions clairement, au niveau de l'élève.`;

    const parts: Record<string, unknown>[] = [
      { text: schoolContext },
    ];

    if (image?.base64) {
      parts.push({
        inline_data: {
          mime_type: String(image.mimeType ?? "image/jpeg"),
          data: String(image.base64),
        },
      });
    }

    if (message) parts.push({ text: message });

    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash";
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "x-goog-api-key": apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts }],
          generationConfig: { temperature: 0.4 },
        }),
      },
    );

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data?.error?.message ?? "Gemini request failed.");
    }

    const text = data?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim();

    if (!text) throw new Error("Gemini returned an empty response.");

    return new Response(JSON.stringify({ text }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : "Unknown error",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
