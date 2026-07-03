import { type NextRequest } from "next/server";
import { z, ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseDeviceHealthRequest } from "@/lib/device-contract";
import {
  parseJsonRequest,
  rateLimit,
  RequestGuardError,
  requestGuardFailure,
} from "@/lib/request-guards";
import {
  currentClerkIdentity,
  hasQuietGateDataConfig,
  recordQuietGateDeviceHealth,
} from "@/lib/quietgate-supabase";

type RouteContext = {
  params: Promise<{
    deviceId: string;
  }>;
};

const deviceIdSchema = z.string().uuid();

export async function POST(request: NextRequest, context: RouteContext) {
  const limited = rateLimit(request, "device-health:post", { limit: 60, windowMs: 60_000 });
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

  try {
    const { deviceId } = await context.params;
    const parsedDeviceId = deviceIdSchema.parse(deviceId);
    const body = await parseJsonRequest(request, 64 * 1024);
    const healthPayload = parseDeviceHealthRequest(body);
    const result = await recordQuietGateDeviceHealth(
      parsedDeviceId,
      healthPayload,
      identity,
    );

    if (!result) {
      return fail(404, "not_found", "Device was not found.");
    }

    return ok(result, 201);
  } catch (error) {
    if (error instanceof ZodError) {
      return validationFailure(error);
    }

    if (error instanceof SyntaxError) {
      return fail(400, "validation_error", "Request body must be valid JSON.");
    }

    if (error instanceof RequestGuardError) {
      return requestGuardFailure(error);
    }

    return upstreamFailure(error);
  }
}
