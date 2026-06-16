const CLERK_SUPABASE_TOKEN_PATTERNS = [
  /no suitable key/i,
  /wrong key type/i,
  /jwt/i,
  /jwks/i,
];

export function isClerkSupabaseTokenError(message: string) {
  return CLERK_SUPABASE_TOKEN_PATTERNS.some((pattern) =>
    pattern.test(message),
  );
}

export function formatSupabaseError(error: unknown) {
  const message =
    error instanceof Error ? error.message : "Unable to reach Supabase.";

  if (!isClerkSupabaseTokenError(message)) {
    return message;
  }

  return [
    "Clerk sign-in is working, but Supabase is rejecting the Clerk session token.",
    "Activate Clerk's Supabase integration, then add Clerk as a third-party auth provider in Supabase for this project.",
    `Raw error: ${message}`,
  ].join(" ");
}

export function supabaseErrorCode(error: unknown) {
  const errorMessage = formatSupabaseError(error);

  return isClerkSupabaseTokenError(errorMessage)
    ? "clerk_supabase_integration_required"
    : "supabase_error";
}
