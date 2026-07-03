import { fail, ok, upstreamFailure } from "@/lib/api-response";
import { rateLimit } from "@/lib/request-guards";
import {
  countQuietGateDevices,
  currentClerkIdentity,
  ensureQuietGateAccount,
  hasQuietGateDataConfig,
} from "@/lib/quietgate-supabase";
import { type NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const limited = rateLimit(request, "me:get", { limit: 120, windowMs: 60_000 });
  if (limited) {
    return limited;
  }

  const clerkUser = await currentClerkIdentity(request);

  if (!clerkUser) {
    return fail(401, "unauthorized", "Unauthorized.");
  }

  if (!hasQuietGateDataConfig()) {
    return fail(
      503,
      "supabase_not_configured",
      "Supabase configuration is not set.",
    );
  }

  try {
    const account = await ensureQuietGateAccount(clerkUser.email, clerkUser);
    const deviceCount = await countQuietGateDevices(clerkUser);

    return ok({
      clerkUserId: clerkUser.userId,
      authSource: clerkUser.source,
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
