import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: { name?: string; email?: string; message?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { name, email, message } = body;
  if (!name?.trim() || !email?.trim() || !message?.trim()) {
    return new Response(JSON.stringify({ error: "name, email, and message are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return new Response(JSON.stringify({ error: "Invalid email address" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { error: dbError } = await supabase
    .from("support_messages")
    .insert({ name: name.trim(), email: email.trim(), message: message.trim() });

  if (dbError) {
    console.error("[support-contact] DB error:", dbError);
    return new Response(JSON.stringify({ error: "Failed to save message" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const toEmail = Deno.env.get("SUPPORT_TO_EMAIL");

  if (resendKey && toEmail) {
    try {
      const emailRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "ChronoSync Support <support@chronosync.app>",
          to: [toEmail],
          reply_to: email.trim(),
          subject: `Support message from ${name.trim()}`,
          html: `
            <h2>New support message</h2>
            <p><strong>From:</strong> ${name.trim()} &lt;${email.trim()}&gt;</p>
            <p><strong>Message:</strong></p>
            <blockquote style="border-left:3px solid #1a6ef5;padding-left:12px;margin-left:0;color:#444">
              ${message.trim().replace(/\n/g, "<br>")}
            </blockquote>
          `,
        }),
      });

      if (!emailRes.ok) {
        const errBody = await emailRes.text();
        console.error("[support-contact] Resend error:", errBody);
      }
    } catch (emailErr) {
      console.error("[support-contact] Email send failed:", emailErr);
    }
  } else {
    console.warn("[support-contact] RESEND_API_KEY or SUPPORT_TO_EMAIL not set — message stored only");
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
