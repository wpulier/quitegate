import { type NextRequest } from "next/server";
import { ZodError, z } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseSiteUsageReportRequest } from "@/lib/site-usage-contract";
import {
  currentClerkIdentity,
  hasQuietGateDataConfig,
  recordQuietGateSiteUsage,
} from "@/lib/quietgate-supabase";

type RouteContext = {
  params: Promise<{
    deviceId: string;
  }>;
};

const deviceIdSchema = z.string().uuid();

export async function POST(request: NextRequest, context: RouteContext) {
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
    const { deviceId } = await context.params;
    const parsedDeviceId = deviceIdSchema.parse(deviceId);
    const body = await request.json();
    const input = parseSiteUsageReportRequest(body);
    const siteUsageSummary = await recordQuietGateSiteUsage(
      parsedDeviceId,
      input,
      identity,
    );

    if (!siteUsageSummary) {
      return fail(404, "not_found", "Tortoise device was not found.");
    }

    return ok({ siteUsageSummary }, 201);
  } catch (error) {
    if (error instanceof ZodError) {
      return validationFailure(error);
    }

    if (error instanceof SyntaxError) {
      return fail(400, "validation_error", "Request body must be valid JSON.");
    }

    return upstreamFailure(error);
  }
}
