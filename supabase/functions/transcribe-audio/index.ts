// transcribe-audio Edge Function
// Transcribes an audio file stored in Supabase Storage using AssemblyAI.
// Returns the full transcript text plus word-level timestamps.

// TODO: Uncomment when Supabase project is configured
// import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface TranscribeAudioRequest {
  audio_url: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { audio_url } =
      (await req.json()) as TranscribeAudioRequest;

    if (!audio_url) {
      return new Response(
        JSON.stringify({ error: "Missing required field: audio_url" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // TODO: Step 1 — Call AssemblyAI transcription API
    //   Use Deno.env.get("ASSEMBLYAI_API_KEY") for auth
    //   POST to https://api.assemblyai.com/v2/transcript
    // TODO: Step 2 — Poll GET /v2/transcript/{id} until status is "completed"
    // TODO: Step 3 — Return transcript with word-level timestamps

    const response = {
      transcript: "placeholder transcript",
      words: [] as Array<{ text: string; start: number; end: number }>,
    };

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
