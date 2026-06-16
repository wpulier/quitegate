import { NextResponse } from "next/server";
import { ZodError } from "zod";
import { formatSupabaseError, supabaseErrorCode } from "@/lib/supabase-errors";

export type ApiErrorCode =
  | "unauthorized"
  | "supabase_not_configured"
  | "validation_error"
  | "policy_version_conflict"
  | "not_found"
  | "supabase_error"
  | "clerk_supabase_integration_required";

export type ApiError = {
  code: ApiErrorCode;
  message: string;
  details?: unknown;
};

export function ok<T>(data: T, status = 200) {
  return NextResponse.json({ ok: true, data }, { status });
}

export function fail(status: number, code: ApiErrorCode, message: string, details?: unknown) {
  const error: ApiError = { code, message };
  if (details !== undefined) {
    error.details = details;
  }

  return NextResponse.json({ ok: false, error }, { status });
}

export function validationFailure(error: ZodError) {
  return fail(400, "validation_error", "Invalid request body.", error.flatten());
}

export function upstreamFailure(error: unknown) {
  return fail(502, supabaseErrorCode(error), formatSupabaseError(error));
}
