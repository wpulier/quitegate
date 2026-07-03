import "server-only";

import { verifyToken } from "@clerk/backend";
import { auth } from "@clerk/nextjs/server";

export type QuietGateIdentity = {
  userId: string;
  email: string | null;
  source: "web" | "bearer";
};

function claimString(claims: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = claims[key];
    if (typeof value === "string" && value.trim()) {
      return value;
    }
  }

  return null;
}

function emailFromClaims(claims: Record<string, unknown>) {
  const directEmail = claimString(claims, [
    "email",
    "email_address",
    "primary_email",
  ]);

  if (directEmail) {
    return directEmail;
  }

  const publicMetadata = claims.public_metadata;
  if (publicMetadata && typeof publicMetadata === "object") {
    return claimString(publicMetadata as Record<string, unknown>, ["email"]);
  }

  return null;
}

function bearerTokenFromRequest(request?: Request) {
  const header = request?.headers.get("authorization");
  if (!header) {
    return null;
  }

  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function csvEnv(name: string) {
  return (process.env[name] ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

async function identityFromBearer(token: string) {
  const secretKey = process.env.CLERK_SECRET_KEY;
  if (!secretKey?.trim()) {
    return null;
  }

  try {
    const audiences = csvEnv("CLERK_JWT_AUDIENCE");
    const authorizedParties = csvEnv("CLERK_AUTHORIZED_PARTIES");
    const payload = await verifyToken(token, {
      secretKey,
      ...(audiences.length > 0 ? { audience: audiences } : {}),
      ...(authorizedParties.length > 0 ? { authorizedParties } : {}),
    });
    const claims = payload as Record<string, unknown>;
    const userId = claims.sub;

    if (typeof userId !== "string" || !userId) {
      return null;
    }

    return {
      userId,
      email: emailFromClaims(claims),
      source: "bearer" as const,
    };
  } catch {
    return null;
  }
}

export async function currentQuietGateIdentity(request?: Request) {
  const bearerToken = bearerTokenFromRequest(request);
  if (bearerToken) {
    return identityFromBearer(bearerToken);
  }

  const { sessionClaims, userId } = await auth();
  if (!userId) {
    return null;
  }

  return {
    userId,
    email: emailFromClaims((sessionClaims ?? {}) as Record<string, unknown>),
    source: "web" as const,
  };
}
