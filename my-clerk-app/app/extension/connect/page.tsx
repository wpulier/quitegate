import { auth } from "@clerk/nextjs/server";
import { SignInButton } from "@clerk/nextjs";
import { ZodError } from "zod";
import { ExtensionConnectClient } from "@/app/extension/connect/ExtensionConnectClient";
import { parseExtensionLinkRequest } from "@/lib/extension-contract";
import { createExtensionLinkCode, ExtensionAuthError } from "@/lib/quietgate-extension";
import { hasSupabaseAdminConfig } from "@/lib/supabase-admin";

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function firstParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ExtensionConnectPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const { userId } = await auth();
  const linkRequest = {
    extensionId: firstParam(params.extensionId),
    installationId: firstParam(params.installationId),
    nonce: firstParam(params.nonce),
    extensionVersion: firstParam(params.extensionVersion) ?? null,
  };

  let payload:
    | {
        extensionId: string;
        installationId: string;
        nonce: string;
        extensionVersion: string | null;
        code: string;
        expiresAt: string;
      }
    | null = null;
  let error: string | null = null;

  if (!hasSupabaseAdminConfig()) {
    error = "QuietGate extension sync is not configured yet.";
  } else if (userId) {
    try {
      const parsed = parseExtensionLinkRequest(linkRequest);
      const linkCode = await createExtensionLinkCode(parsed);
      payload = {
        ...parsed,
        code: linkCode.code,
        expiresAt: linkCode.expiresAt,
      };
    } catch (caught) {
      if (caught instanceof ZodError) {
        error = "QuietGate for Chrome opened an invalid connection URL.";
      } else if (caught instanceof ExtensionAuthError) {
        error = caught.message;
      } else {
        error = caught instanceof Error ? caught.message : "Unable to create a Chrome extension link code.";
      }
    }
  }

  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto flex w-full max-w-3xl flex-col gap-8 px-6 py-20">
        <div>
          <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Extension sync
          </p>
          <h1 className="text-4xl font-semibold tracking-tight text-zinc-950">
            Connect QuietGate for Chrome.
          </h1>
          <p className="mt-5 text-lg leading-8 text-zinc-600">
            This links Chrome to your QuietGate account so it can read your shared protection policy and report health.
          </p>
        </div>

        {!userId ? (
          <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Account required</p>
            <p className="mt-2 text-2xl font-semibold text-zinc-950">Sign in to continue</p>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              QuietGate needs your Clerk account before it can link this browser.
            </p>
            <SignInButton>
              <button className="mt-5 rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white">
                Sign in
              </button>
            </SignInButton>
          </div>
        ) : payload ? (
          <ExtensionConnectClient payload={payload} />
        ) : (
          <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Connection failed</p>
            <p className="mt-2 text-2xl font-semibold text-zinc-950">Needs attention</p>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              {error || "QuietGate could not prepare extension setup."}
            </p>
          </div>
        )}
      </section>
    </main>
  );
}
