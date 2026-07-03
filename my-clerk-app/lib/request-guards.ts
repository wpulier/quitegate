import "server-only";

import { fail, type ApiErrorCode } from "@/lib/api-response";

type RateLimitOptions = {
  limit: number;
  windowMs: number;
};

type RateBucket = {
  count: number;
  resetAt: number;
};

const rateBuckets = new Map<string, RateBucket>();

export class RequestGuardError extends Error {
  status: number;
  code: ApiErrorCode;

  constructor(status: number, code: ApiErrorCode, message: string) {
    super(message);
    this.name = "RequestGuardError";
    this.status = status;
    this.code = code;
  }
}

export async function parseJsonRequest(request: Request, maxBytes = 64 * 1024) {
  const contentLength = request.headers.get("content-length");
  if (contentLength && Number(contentLength) > maxBytes) {
    throw new RequestGuardError(
      413,
      "payload_too_large",
      "Request body is too large.",
    );
  }

  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    throw new RequestGuardError(
      413,
      "payload_too_large",
      "Request body is too large.",
    );
  }

  return JSON.parse(text);
}

export function requestGuardFailure(error: RequestGuardError) {
  return fail(error.status, error.code, error.message);
}

export function rateLimit(
  request: Request,
  bucket: string,
  options: RateLimitOptions = { limit: 60, windowMs: 60_000 },
) {
  const now = Date.now();
  const key = `${bucket}:${rateLimitIdentity(request)}`;
  const current = rateBuckets.get(key);

  if (!current || current.resetAt <= now) {
    rateBuckets.set(key, { count: 1, resetAt: now + options.windowMs });
    return null;
  }

  current.count += 1;
  if (current.count <= options.limit) {
    return null;
  }

  return fail(429, "rate_limited", "Too many requests. Try again shortly.", {
    retryAfterSeconds: Math.max(Math.ceil((current.resetAt - now) / 1000), 1),
  });
}

function rateLimitIdentity(request: Request) {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const realIP = request.headers.get("x-real-ip")?.trim();
  const authorization = request.headers.get("authorization")?.slice(0, 80);
  return forwarded || realIP || authorization || "unknown";
}
