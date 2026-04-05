import Stripe from "https://esm.sh/stripe@14?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return new Response("Missing stripe-signature header", { status: 400 });
  }

  const body = await req.text();
  let event: Stripe.Event;

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response("Invalid signature", { status: 400 });
  }

  console.log("Stripe event received:", event.type);

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const sub = event.data.object as Stripe.Subscription;
      const customerId = sub.customer as string;
      const isActive = sub.status === "active" || sub.status === "trialing";
      const newTier = isActive ? "pro" : "free";

      const { error } = await supabase
        .from("profiles")
        .update({ tier: newTier, updated_at: new Date().toISOString() })
        .eq("stripe_customer_id", customerId);

      if (error) {
        console.error("Failed to update profile tier:", error);
        return new Response("Database error", { status: 500 });
      }

      console.log(`Updated customer ${customerId} to tier: ${newTier}`);
      break;
    }

    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      const customerId = sub.customer as string;

      const { error } = await supabase
        .from("profiles")
        .update({ tier: "free", updated_at: new Date().toISOString() })
        .eq("stripe_customer_id", customerId);

      if (error) {
        console.error("Failed to downgrade profile:", error);
        return new Response("Database error", { status: 500 });
      }

      console.log(`Downgraded customer ${customerId} to free tier`);
      break;
    }

    case "checkout.session.completed": {
      // Associate Stripe customer ID with the Supabase user
      const session = event.data.object as Stripe.Checkout.Session;
      const customerId = session.customer as string;
      const userEmail = session.customer_email;

      if (userEmail) {
        // Find the user by email and store their Stripe customer ID
        const { data: users } = await supabase.auth.admin.listUsers();
        const user = users?.users.find((u) => u.email === userEmail);

        if (user) {
          await supabase
            .from("profiles")
            .update({ stripe_customer_id: customerId })
            .eq("id", user.id);
          console.log(`Linked Stripe customer ${customerId} to user ${user.id}`);
        }
      }
      break;
    }

    default:
      console.log("Unhandled event type:", event.type);
  }

  return new Response("ok", { status: 200 });
});
