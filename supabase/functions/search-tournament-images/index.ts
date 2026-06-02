import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SPORT_KEYWORDS: Record<string, string> = {
  "Tenisas": "tennis trophy championship",
  "Padelis": "padel tournament court",
  "Pickleball": "pickleball tournament",
  "Badmintonas": "badminton championship",
  "Skvošas": "squash tournament",
  "Stalo tenisas": "table tennis tournament trophy",
  "Krepšinis": "basketball championship trophy",
  "Futbolas": "soccer football championship trophy",
  "Tinklinis": "volleyball tournament",
  "Paplūdimio tinklinis": "beach volleyball tournament",
  "Smiginis": "darts championship",
  "Boulingas": "bowling tournament",
  "Biliardas": "billiards championship",
  "Poolas": "pool billiards tournament",
  "Snukeris": "snooker championship",
  "Dažasvydis": "paintball tournament",
  "Rankinis": "handball championship",
};

interface StockImage {
  image_url: string;
  thumb_url: string;
  photographer: string;
  source: "unsplash" | "pexels" | "pixabay";
  source_url: string;
  width: number;
  height: number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("method not allowed", 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonError("unauthorized", 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !anonKey) {
      return jsonError("server configuration missing", 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return jsonError("unauthorized", 401);

    const body = await req.json();
    const { sport_code, custom_query, page = 1 } = body;
    if (!sport_code) return jsonError("sport_code required", 400);

    const baseQuery = SPORT_KEYWORDS[sport_code] || sport_code;
    const query = custom_query
      ? `${baseQuery} ${custom_query}`
      : baseQuery;

    const [unsplash, pexels, pixabay] = await Promise.all([
      searchUnsplash(query, page).catch((e) => {
        console.error("Unsplash error:", e);
        return [];
      }),
      searchPexels(query, page).catch((e) => {
        console.error("Pexels error:", e);
        return [];
      }),
      searchPixabay(query, page).catch((e) => {
        console.error("Pixabay error:", e);
        return [];
      }),
    ]);

    const all = [...unsplash, ...pexels, ...pixabay];
    const seen = new Set<string>();
    const unique = all.filter((img) => {
      if (seen.has(img.image_url)) return false;
      seen.add(img.image_url);
      return true;
    });

    return jsonOk({ images: unique, query, total: unique.length });
  } catch (err) {
    console.error("Error:", err);
    return jsonError(String(err), 500);
  }
});

async function searchUnsplash(
  query: string,
  page: number,
): Promise<StockImage[]> {
  const key = Deno.env.get("UNSPLASH_ACCESS_KEY");
  if (!key) return [];

  const url =
    `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&page=${page}&per_page=10&orientation=landscape`;
  const resp = await fetch(url, {
    headers: { Authorization: `Client-ID ${key}` },
  });
  if (!resp.ok) throw new Error(`Unsplash ${resp.status}`);
  const data = await resp.json();

  return (data.results || []).map((img: {
    urls: { regular: string; small: string };
    user: { name: string };
    links: { html: string };
    width: number;
    height: number;
  }) => ({
    image_url: img.urls.regular,
    thumb_url: img.urls.small,
    photographer: img.user.name,
    source: "unsplash" as const,
    source_url: img.links.html,
    width: img.width,
    height: img.height,
  }));
}

async function searchPexels(query: string, page: number): Promise<StockImage[]> {
  const key = Deno.env.get("PEXELS_API_KEY");
  if (!key) return [];

  const url =
    `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&page=${page}&per_page=10&orientation=landscape`;
  const resp = await fetch(url, { headers: { Authorization: key } });
  if (!resp.ok) throw new Error(`Pexels ${resp.status}`);
  const data = await resp.json();

  return (data.photos || []).map((img: {
    src: { large: string; medium: string };
    photographer: string;
    url: string;
    width: number;
    height: number;
  }) => ({
    image_url: img.src.large,
    thumb_url: img.src.medium,
    photographer: img.photographer,
    source: "pexels" as const,
    source_url: img.url,
    width: img.width,
    height: img.height,
  }));
}

async function searchPixabay(
  query: string,
  page: number,
): Promise<StockImage[]> {
  const key = Deno.env.get("PIXABAY_API_KEY");
  if (!key) return [];

  const url =
    `https://pixabay.com/api/?key=${key}&q=${encodeURIComponent(query)}&page=${page}&per_page=10&image_type=photo&orientation=horizontal&safesearch=true`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Pixabay ${resp.status}`);
  const data = await resp.json();

  return (data.hits || []).map((img: {
    largeImageURL: string;
    webformatURL: string;
    user: string;
    pageURL: string;
    imageWidth: number;
    imageHeight: number;
  }) => ({
    image_url: img.largeImageURL,
    thumb_url: img.webformatURL,
    photographer: img.user,
    source: "pixabay" as const,
    source_url: img.pageURL,
    width: img.imageWidth,
    height: img.imageHeight,
  }));
}

function jsonOk(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(msg: string, status: number) {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
