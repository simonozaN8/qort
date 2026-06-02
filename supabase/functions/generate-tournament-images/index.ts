import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DAILY_GENERATION_LIMIT = 3; // 3 × 3 vaizdai = 9 per parą

const SPORT_DESCRIPTIONS: Record<string, string> = {
  "Tenisas": "tennis",
  "Padelis": "padel",
  "Pickleball": "pickleball",
  "Badmintonas": "badminton",
  "Skvošas": "squash",
  "Stalo tenisas": "table tennis ping pong",
  "Krepšinis": "basketball",
  "Futbolas": "football soccer",
  "Tinklinis": "indoor volleyball",
  "Paplūdimio tinklinis": "beach volleyball",
  "Smiginis": "darts",
  "Boulingas": "bowling",
  "Biliardas": "billiards pool",
  "Poolas": "pool billiards",
  "Snukeris": "snooker",
  "Dažasvydis": "paintball",
  "Rankinis": "handball",
};

const SPORT_STYLES = [
  {
    tag: "trophy_hero",
    promptModifier: `EXTREME CLOSE-UP HERO SHOT of a large golden 
      championship trophy in the center, taking up 60% of the frame. 
      Sport equipment (racket, ball, court fragment) ONLY as soft 
      blurred background. Dramatic stage lighting, lens flare, 
      premium product photography style. The trophy is the SUBJECT. 
      ABSOLUTELY NO PEOPLE, NO FACES.`,
  },
  {
    tag: "podium_scene",
    promptModifier: `WIDE STADIUM scene with empty 3-tier winners 
      podium in the center foreground, championship trophy on the 
      top tier. Stadium seats with crowd as blurred background. 
      Confetti or spotlight beams visible. Tournament finale 
      atmosphere. NO RECOGNIZABLE FACES - crowd is distant blur only.`,
  },
  {
    tag: "trophy_minimal",
    promptModifier: `MINIMALIST flat vector poster (NOT photo). Big 
      bold trophy silhouette in center, sport ball next to it, 2-3 
      colors max (gold/dark/accent). Modern championship poster 
      design like Behance artwork. NO realistic textures. NO PEOPLE.`,
  },
];

type QuotaPayload = {
  used: number;
  limit: number;
  is_super_admin: boolean;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("method not allowed", 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonError("missing authorization header", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return jsonError("server configuration missing", 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authErr,
  } = await userClient.auth.getUser();

  if (authErr || !user) {
    return jsonError(
      "unauthorized: " + (authErr?.message ?? "invalid JWT"),
      401,
    );
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  try {
    const body = await req.json();
    const { mode, sport_code } = body;

    if (!sport_code) {
      return jsonError("sport_code required", 400);
    }

    const isSuperAdmin = await resolveSuperAdmin(supabaseAdmin, user.id);
    const quota = await computeQuota(supabaseAdmin, user.id, isSuperAdmin);

    if (mode === "list_pool") {
      const { data, error } = await supabaseAdmin
        .from("sport_image_templates")
        .select("*")
        .eq("sport_code", sport_code)
        .eq("aspect_ratio", "16:9")
        .eq("is_active", true)
        .order("usage_count", { ascending: false });

      if (error) throw error;
      return jsonOk({ templates: data || [], quota });
    }

    if (mode === "pool_generate") {
      if (!isSuperAdmin && quota.used >= DAILY_GENERATION_LIMIT) {
        return jsonError(
          `Pasiekei limitą - ${DAILY_GENERATION_LIMIT} generavimai per parą. ` +
            `Pasirink iš esamų cache vaizdų arba laukk rytdienos.`,
          429,
        );
      }

      const sportDesc = SPORT_DESCRIPTIONS[sport_code];
      if (!sportDesc) {
        return jsonError(
          `Unknown sport: ${sport_code}. Expected Lithuanian name like "Tenisas".`,
          400,
        );
      }

      const geminiKey = Deno.env.get("GEMINI_API_KEY");
      if (!geminiKey) return jsonError("GEMINI_API_KEY not configured", 500);

      const results = await Promise.all(
        SPORT_STYLES.map((style) =>
          generateAndStore(
            supabaseAdmin,
            sport_code,
            style.tag,
            buildPrompt(sportDesc, style),
            geminiKey,
            user.id,
          )
        ),
      );

      const quotaAfter = await computeQuota(supabaseAdmin, user.id, isSuperAdmin);
      return jsonOk({ templates: results, quota: quotaAfter });
    }

    return jsonError("invalid mode", 400);
  } catch (err) {
    console.error("Error:", err);
    return jsonError(String(err), 500);
  }
});

function buildPrompt(
  sportDesc: string,
  style: { promptModifier: string },
): string {
  return `CHAMPIONSHIP TOURNAMENT visual for the sport: ${sportDesc}. ` +
    `This is a COMPETITIVE tournament prize/podium scene, NOT regular ` +
    `practice or casual play. ` +
    `Create a 16:9 landscape championship poster background. ` +
    `STRICT RULES: ` +
    `- NO TEXT, NO LOGOS, NO LETTERS, NO WORDS, NO NUMBERS, NO BRAND NAMES. ` +
    `- NO recognizable human faces. ` +
    `- A trophy or medal MUST be visible and prominent. ` +
    `- Tournament finale atmosphere, not training session. ` +
    `- Leave negative space on the left third for overlay text. ` +
    `${style.promptModifier}`;
}

async function resolveSuperAdmin(
  supabaseAdmin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("is_super_admin")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    const msg = error.message ?? "";
    if (
      msg.includes("is_super_admin") ||
      msg.includes("column") ||
      error.code === "42703"
    ) {
      console.warn(
        "profiles.is_super_admin missing — run migration 20260528000001. Treating as non-admin.",
      );
      return false;
    }
    console.warn("super-admin lookup failed:", error);
    return false;
  }

  return data?.is_super_admin === true;
}

async function computeQuota(
  supabaseAdmin: SupabaseClient,
  userId: string,
  isSuperAdmin: boolean,
): Promise<QuotaPayload> {
  if (isSuperAdmin) {
    return {
      used: 0,
      limit: DAILY_GENERATION_LIMIT,
      is_super_admin: true,
    };
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error } = await supabaseAdmin
    .from("sport_image_templates")
    .select("id", { count: "exact", head: true })
    .eq("created_by", userId)
    .gte("created_at", since);

  if (error) throw error;

  const used = Math.floor((count ?? 0) / 3);
  return {
    used,
    limit: DAILY_GENERATION_LIMIT,
    is_super_admin: false,
  };
}

async function generateAndStore(
  supabaseAdmin: SupabaseClient,
  sportCode: string,
  styleTag: string,
  prompt: string,
  geminiKey: string,
  userId: string,
) {
  const geminiResp = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent",
    {
      method: "POST",
      headers: {
        "x-goog-api-key": geminiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [{
          role: "user",
          parts: [{ text: prompt }],
        }],
        generationConfig: {
          responseModalities: ["IMAGE"],
          imageConfig: { aspectRatio: "16:9" },
        },
      }),
    },
  );

  if (!geminiResp.ok) {
    const errText = await geminiResp.text();
    throw new Error(`Gemini API ${geminiResp.status}: ${errText}`);
  }

  const data = await geminiResp.json();

  const part = data.candidates?.[0]?.content?.parts?.find(
    (p: { inlineData?: { data?: string }; inline_data?: { data?: string } }) =>
      p.inlineData || p.inline_data,
  );
  if (!part) {
    throw new Error("No image in Gemini response: " + JSON.stringify(data));
  }

  const base64 = part.inlineData?.data || part.inline_data?.data;
  const mimeType =
    part.inlineData?.mimeType || part.inline_data?.mime_type || "image/png";

  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  const safeSportCode = sportCode
    .toLowerCase()
    .replace(
      /[ąčęėįšųūž]/g,
      (c) =>
        ({ ą: "a", č: "c", ę: "e", ė: "e", į: "i", š: "s", ų: "u", ū: "u", ž: "z" })[
          c
        ] || c,
    )
    .replace(/[^a-z0-9]/g, "_");

  const filename = `templates/${safeSportCode}/${crypto.randomUUID()}.png`;
  const { error: uploadErr } = await supabaseAdmin.storage
    .from("tournament-images")
    .upload(filename, bytes, {
      contentType: mimeType,
      upsert: false,
    });
  if (uploadErr) throw new Error("Storage upload: " + uploadErr.message);

  const { data: urlData } = supabaseAdmin.storage
    .from("tournament-images")
    .getPublicUrl(filename);

  const { data: templateRow, error: dbErr } = await supabaseAdmin
    .from("sport_image_templates")
    .insert({
      sport_code: sportCode,
      image_url: urlData.publicUrl,
      aspect_ratio: "16:9",
      style_tag: styleTag,
      prompt_used: prompt,
      created_by: userId,
      is_active: true,
    })
    .select()
    .single();

  if (dbErr) throw new Error("DB insert: " + dbErr.message);
  return templateRow;
}

function jsonOk(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
