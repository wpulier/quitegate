import { type NextRequest } from "next/server";
import { fail, ok, upstreamFailure } from "@/lib/api-response";
import { rateLimit } from "@/lib/request-guards";
import {
  currentClerkIdentity,
  getQuietGateSiteUsageSummary,
  hasQuietGateDataConfig,
} from "@/lib/quietgate-supabase";

export async function GET(request: NextRequest) {
  const limited = rateLimit(request, "usage:get", { limit: 120, windowMs: 60_000 });
  if (limited) {
    return limited;
  }

  if (!hasQuietGateDataConfig()) {
    return fail(
      503,
      "supabase_not_configured",
      "Supabase configuration is not set.",
    );
  }

  const identity = await currentClerkIdentity(request);
  if (!identity) {
    return fail(401, "unauthorized", "Unauthorized.");
  }

  // Clients pass their local calendar date so "today" is the user's day,
  // not the server's (UTC) day.
  const requestedDate = request.nextUrl.searchParams.get("date");
  if (requestedDate && !/^\d{4}-\d{2}-\d{2}$/.test(requestedDate)) {
    return fail(400, "validation_error", "date must be formatted YYYY-MM-DD.");
  }

  try {
    const siteUsageSummary = await getQuietGateSiteUsageSummary(
      identity,
      requestedDate ?? undefined,
    );
    return ok({ siteUsageSummary });
  } catch (error) {
    return upstreamFailure(error);
  }
}
