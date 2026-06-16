import { fail, ok, upstreamFailure } from "@/lib/api-response";
import {
  countQuietGateDevices,
  currentClerkIdentity,
  ensureQuietGateAccount,
} from "@/lib/quietgate-supabase";
import { hasSupabasePublicConfig } from "@/lib/supabase-clerk";

export async function GET() {
  const clerkUser = await currentClerkIdentity();

  if (!clerkUser) {
    return fail(401, "unauthorized", "Unauthorized.");
  }

  if (!hasSupabasePublicConfig()) {
    return fail(
      503,
      "supabase_not_configured",
      "Supabase public configuration is not set.",
    );
  }

  try {
    const account = await ensureQuietGateAccount(clerkUser.email);
    const deviceCount = await countQuietGateDevices();

    return ok({
      clerkUserId: clerkUser.userId,
      user: {
        id: account.user.id,
        primaryEmail: account.user.primary_email,
      },
      policy: account.policy,
      deviceCount,
    });
  } catch (error) {
    return upstreamFailure(error);
  }
}
