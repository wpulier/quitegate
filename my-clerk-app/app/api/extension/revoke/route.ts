import { type NextRequest } from "next/server";
import { fail, ok, upstreamFailure } from "@/lib/api-response";
import { ExtensionAuthError, revokeExtensionDevice } from "@/lib/quietgate-extension";
import { rateLimit } from "@/lib/request-guards";
import { hasSupabaseAdminConfig } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  const limited = rateLimit(request, "extension-revoke:post", { limit: 30, windowMs: 60_000 });
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
    return ok(await revokeExtensionDevice(request.headers.get("authorization")));
  } catch (error) {
    if (error instanceof ExtensionAuthError) {
      return fail(error.status, error.code, error.message);
    }

    return upstreamFailure(error);
  }
}
