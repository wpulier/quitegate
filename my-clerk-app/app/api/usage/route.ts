import { type NextRequest } from "next/server";
import { fail, ok, upstreamFailure } from "@/lib/api-response";
import {
  currentClerkIdentity,
  getQuietGateSiteUsageSummary,
  hasQuietGateDataConfig,
} from "@/lib/quietgate-supabase";

export async function GET(request: NextRequest) {
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

  try {
    const siteUsageSummary = await getQuietGateSiteUsageSummary(identity);
    return ok({ siteUsageSummary });
  } catch (error) {
    return upstreamFailure(error);
  }
}
