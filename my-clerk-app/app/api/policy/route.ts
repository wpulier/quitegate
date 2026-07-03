import { type NextRequest } from "next/server";
import { ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parsePolicyUpdateRequest } from "@/lib/policy-contract";
import {
  parseJsonRequest,
  rateLimit,
  RequestGuardError,
  requestGuardFailure,
} from "@/lib/request-guards";
import {
  currentClerkIdentity,
  getQuietGatePolicy,
  hasQuietGateDataConfig,
  PolicyVersionConflictError,
  updateQuietGatePolicy,
} from "@/lib/quietgate-supabase";

export async function GET(request: NextRequest) {
  const limited = rateLimit(request, "policy:get", { limit: 120, windowMs: 60_000 });
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
    return ok(await getQuietGatePolicy(identity));
  } catch (error) {
    return upstreamFailure(error);
  }
}

export async function PUT(request: NextRequest) {
  const limited = rateLimit(request, "policy:put", { limit: 30, windowMs: 60_000 });
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
    const body = await parseJsonRequest(request, 128 * 1024);
    const updateRequest = parsePolicyUpdateRequest(body);
    const policy = await updateQuietGatePolicy(
      updateRequest.expectedSettingsVersion,
      updateRequest.policy,
      identity,
    );

    return ok(policy);
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
