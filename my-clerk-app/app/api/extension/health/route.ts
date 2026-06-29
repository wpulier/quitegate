import { type NextRequest } from "next/server";
import { ZodError } from "zod";
import { fail, ok, upstreamFailure, validationFailure } from "@/lib/api-response";
import { parseExtensionHealthRequest } from "@/lib/extension-contract";
import { ExtensionAuthError, recordExtensionHealth } from "@/lib/quietgate-extension";
import { hasSupabaseAdminConfig } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  if (!hasSupabaseAdminConfig()) {
    return fail(
      503,
      "extension_not_configured",
      "QuietGate extension sync is not configured.",
    );
  }

  try {
    const body = await request.json();
    const input = parseExtensionHealthRequest(body);
    return ok(await recordExtensionHealth(request.headers.get("authorization"), input), 201);
  } catch (error) {
    if (error instanceof ZodError) {
      return validationFailure(error);
    }

    if (error instanceof SyntaxError) {
      return fail(400, "validation_error", "Request body must be valid JSON.");
    }

    if (error instanceof ExtensionAuthError) {
      return fail(error.status, error.code, error.message);
    }

    return upstreamFailure(error);
  }
}
