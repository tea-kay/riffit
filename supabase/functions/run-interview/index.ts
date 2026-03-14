// run-interview Edge Function
// Powers the AI onboarding interview. Maintains a conversation with
// the creator to build their CreatorProfile. Branches based on
// creator_type to ask different questions for each type.

// TODO: Uncomment when Supabase project is configured
// import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RunInterviewRequest {
  session_id: string;
  user_message: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { session_id, user_message } =
      (await req.json()) as RunInterviewRequest;

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: session_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // TODO: Step 1 — Fetch OnboardingSession (conversation_history, creator_type)
    // TODO: Step 2 — Select correct interview prompt tree based on creator_type
    //   - personal_brand: origin story, defining moments, opinions
    //   - educator: expertise, frameworks, audience transformation
    //   - entertainer: format, personality, recurring bits
    //   - business: product, customer pain, proof points
    //   - agency: client results, positioning, team voice
    // TODO: Step 3 — Call Claude API with full conversation history
    //   Use Deno.env.get("ANTHROPIC_API_KEY") for auth
    //   Interview must be conversational, warm, curious — one question at a time
    // TODO: Step 4 — Append AI response to conversation_history
    // TODO: Step 5 — Detect completion, extract structured data, create CreatorProfile

    const response = {
      ai_message: "placeholder response",
      is_complete: false,
      creator_profile_id: null,
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
