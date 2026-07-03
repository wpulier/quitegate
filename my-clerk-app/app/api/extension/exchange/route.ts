import { type NextRequest } from "next/server";
import { ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseExtensionExchangeRequest } from "@/lib/extension-contract";
import { exchangeExtensionLinkCode, ExtensionAuthError } from "@/lib/quietgate-extension";
import {
  parseJsonRequest,
  rateLimit,
  RequestGuardError,
  requestGuardFailure,
} from "@/lib/request-guards";
import { hasSupabaseAdminConfig } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  const limited = rateLimit(request, "extension-exchange:post", { limit: 12, windowMs: 60_000 });
  if (limited) {
    return limited;
  }

  if (!hasSupabaseAdminConfig()) {
    return fail(
      503,
      "extension_not_configured",
      "Tortoise extension sync is not configured.",
    );
  }

  try {
    const body = await parseJsonRequest(request, 16 * 1024);
    const input = parseExtensionExchangeRequest(body);
    const result = await exchangeExtensionLinkCode(input);
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

    if (error instanceof ExtensionAuthError) {
      return fail(error.status, error.code, error.message);
    }

    return upstreamFailure(error);
  }
}
