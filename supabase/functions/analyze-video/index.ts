// analyze-video Edge Function
// Accepts a video URL and platform, transcribes it via AssemblyAI,
// saves the InspirationVideo record, then triggers score-alignment
// and generate-deconstruction.

// TODO: Uncomment when Supabase project is configured
// import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface AnalyzeVideoRequest {
  url: string;
  platform: string;
  creator_profile_id: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { url, platform, creator_profile_id } =
      (await req.json()) as AnalyzeVideoRequest;

    if (!url || !platform || !creator_profile_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: url, platform, creator_profile_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // TODO: Step 1 — Call AssemblyAI to transcribe the video audio
    // Use Deno.env.get("ASSEMBLYAI_API_KEY") for auth

    // TODO: Step 2 — Save InspirationVideo record to Supabase
    // Insert into inspiration_videos table with status: "analyzing"

    // TODO: Step 3 — Trigger score-alignment Edge Function
    // TODO: Step 4 — Trigger generate-deconstruction

    const response = { inspiration_video_id: "placeholder-uuid" };

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
