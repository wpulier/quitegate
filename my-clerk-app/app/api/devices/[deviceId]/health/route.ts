import { type NextRequest } from "next/server";
import { z, ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseDeviceHealthRequest } from "@/lib/device-contract";
import {
  currentClerkIdentity,
  recordQuietGateDeviceHealth,
} from "@/lib/quietgate-supabase";
import { hasSupabasePublicConfig } from "@/lib/supabase-clerk";

type RouteContext = {
  params: Promise<{
    deviceId: string;
  }>;
};

const deviceIdSchema = z.string().uuid();

export async function POST(request: NextRequest, context: RouteContext) {
  if (!hasSupabasePublicConfig()) {
    return fail(
      503,
      "supabase_not_configured",
      "Supabase public configuration is not set.",
    );
  }

  if (!(await currentClerkIdentity())) {
    return fail(401, "unauthorized", "Unauthorized.");
  }

  try {
    const { deviceId } = await context.params;
    const parsedDeviceId = deviceIdSchema.parse(deviceId);
    const body = await request.json();
    const healthPayload = parseDeviceHealthRequest(body);
    const result = await recordQuietGateDeviceHealth(
      parsedDeviceId,
      healthPayload,
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

    return upstreamFailure(error);
  }
}
