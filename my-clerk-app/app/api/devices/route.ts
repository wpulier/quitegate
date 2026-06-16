import { type NextRequest } from "next/server";
import { ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseDeviceRegistrationRequest } from "@/lib/device-contract";
import {
  currentClerkIdentity,
  listQuietGateDevices,
  registerQuietGateDevice,
} from "@/lib/quietgate-supabase";
import { hasSupabasePublicConfig } from "@/lib/supabase-clerk";

export async function GET() {
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
    const devices = await listQuietGateDevices();
    return ok({ devices });
  } catch (error) {
    return upstreamFailure(error);
  }
}

export async function POST(request: NextRequest) {
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
    const body = await request.json();
    const registration = parseDeviceRegistrationRequest(body);
    const device = await registerQuietGateDevice(registration);

    return ok({ device }, 201);
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
