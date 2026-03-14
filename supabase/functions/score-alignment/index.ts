// score-alignment Edge Function
// Scores how well an inspiration video aligns with the creator's brand.
// Fetches the video transcript and creator profile, then calls Claude
// to produce a score (0-100), verdict (skip/consider/strong), and reasoning.

// TODO: Uncomment when Supabase project is configured
// import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ScoreAlignmentRequest {
  inspiration_video_id: string;
  creator_profile_id: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { inspiration_video_id, creator_profile_id } =
      (await req.json()) as ScoreAlignmentRequest;

    if (!inspiration_video_id || !creator_profile_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: inspiration_video_id, creator_profile_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // TODO: Step 1 — Fetch InspirationVideo transcript from Supabase
    // TODO: Step 2 — Fetch CreatorProfile (niche, pillars, tone, never_do)
    // TODO: Step 3 — Call Claude API with alignment scoring prompt
    //   Use Deno.env.get("ANTHROPIC_API_KEY") for auth
    //   Prompt must be opinionated — return a clear verdict with reasoning
    // TODO: Step 4 — Save score, verdict, reasoning back to InspirationVideo

    const response = { score: 0, verdict: "consider", reasoning: "placeholder" };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
