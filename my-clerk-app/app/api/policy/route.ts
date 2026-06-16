import { type NextRequest } from "next/server";
import { ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parsePolicyUpdateRequest } from "@/lib/policy-contract";
import {
  currentClerkIdentity,
  getQuietGatePolicy,
  PolicyVersionConflictError,
  updateQuietGatePolicy,
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
    return ok(await getQuietGatePolicy());
  } catch (error) {
    return upstreamFailure(error);
  }
}

export async function PUT(request: NextRequest) {
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
    const updateRequest = parsePolicyUpdateRequest(body);
    const policy = await updateQuietGatePolicy(
      updateRequest.expectedSettingsVersion,
      updateRequest.policy,
    );

    return ok(policy);
  } catch (error) {
    if (error instanceof ZodError) {
      return validationFailure(error);
    }

    if (error instanceof SyntaxError) {
      return fail(400, "validation_error", "Request body must be valid JSON.");
    }

    if (error instanceof PolicyVersionConflictError) {
      return fail(
        409,
        "policy_version_conflict",
        "Policy has changed since this client loaded it.",
        {
          settingsVersion: error.latest.settingsVersion,
          updatedAt: error.latest.updatedAt,
        },
      );
    }

    return upstreamFailure(error);
  }
}
