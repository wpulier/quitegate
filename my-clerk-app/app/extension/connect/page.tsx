import { auth } from "@clerk/nextjs/server";
import { SignInButton, SignUpButton } from "@clerk/nextjs";
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

function connectionReturnPath(params: Record<string, string | string[] | undefined>) {
  const query = new URLSearchParams();

  for (const [key, value] of Object.entries(params)) {
    if (Array.isArray(value)) {
      for (const item of value) {
        query.append(key, item);
      }
    } else if (value !== undefined) {
      query.set(key, value);
    }
  }

  const encoded = query.toString();
  return encoded ? `/extension/connect?${encoded}` : "/extension/connect";
}

export default async function ExtensionConnectPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const { userId } = await auth();
  const returnPath = connectionReturnPath(params);
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
    error = "Tortoise extension sync is not configured yet.";
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
        error = "Tortoise for Chrome opened an invalid connection URL.";
      } else if (caught instanceof ExtensionAuthError) {
        error = caught.message;
      } else {
        error = caught instanceof Error ? caught.message : "Unable to create a Chrome extension link code.";
      }
    }
  }

  return (
    <main className="bg-[#fbfbef] px-5 py-10 sm:px-6 sm:py-14">
      <section className="mx-auto grid min-h-[calc(100vh-12rem)] w-full max-w-6xl overflow-hidden rounded-2xl border border-zinc-200/90 bg-white shadow-[0_24px_80px_rgba(24,24,27,0.10)] lg:grid-cols-[1.02fr_0.98fr]">
        <div className="flex flex-col justify-between bg-[#101114] p-7 text-white sm:p-10 lg:p-12">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#8ea6ff]">
              QuietGate browser setup
            </p>
            <h1 className="mt-4 max-w-xl text-4xl font-semibold leading-[1.02] tracking-tight sm:text-5xl">
              Bring your protection policy into Chrome.
            </h1>
            <p className="mt-5 max-w-xl text-base leading-7 text-white/64">
              Connect this extension to your Tortoise account so focus rules,
              adult-content protection, and device status stay in sync.
            </p>
          </div>

          <div className="mt-12 grid gap-4">
            {[
              ["1", "Use or create your Tortoise account"],
              ["2", "QuietGate connects this Chrome profile"],
              ["3", "Your protection policy syncs automatically"],
            ].map(([step, label]) => (
              <div className="flex items-center gap-4 border-t border-white/12 pt-4" key={step}>
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[#3e63dd] text-sm font-bold text-white">
                  {step}
                </span>
                <p className="text-sm font-semibold text-white/82">{label}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="flex min-w-0 items-center bg-[#f7f7f1] p-5 sm:p-10 lg:p-12">
          {!userId ? (
            <section className="w-full rounded-2xl border border-zinc-200 bg-white p-6 shadow-[0_18px_54px_rgba(24,24,27,0.09)] sm:p-8" aria-labelledby="connect-account-title">
              <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#3e63dd]">
                Step 1 of 2
              </p>
              <h2 id="connect-account-title" className="mt-3 text-3xl font-semibold tracking-tight text-zinc-950">
                Start with your account.
              </h2>
              <p className="mt-4 text-sm leading-6 text-zinc-600">
                New to Tortoise? Create an account. Already protected on another
                device? Sign in and we will bring you back here automatically.
              </p>
              <div className="mt-7 grid gap-3">
                <SignUpButton fallbackRedirectUrl={returnPath} forceRedirectUrl={returnPath} mode="modal">
                  <button className="min-h-12 rounded-lg bg-[#3e63dd] px-5 text-sm font-semibold text-white transition hover:bg-[#3456c7] focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2">
                    Create account
                  </button>
                </SignUpButton>
                <SignInButton fallbackRedirectUrl={returnPath} forceRedirectUrl={returnPath} mode="modal">
                  <button className="min-h-12 rounded-lg border border-zinc-300 bg-white px-5 text-sm font-semibold text-zinc-900 transition hover:border-zinc-400 hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2">
                    Sign in
                  </button>
                </SignInButton>
              </div>
              <p className="mt-5 text-xs leading-5 text-zinc-500">
                Authentication is handled securely by Clerk. QuietGate receives
                only the account access needed to sync your settings.
              </p>
            </section>
          ) : payload ? (
            <ExtensionConnectClient payload={payload} />
          ) : (
            <section className="w-full rounded-2xl border border-rose-200 bg-white p-6 shadow-[0_18px_54px_rgba(24,24,27,0.09)] sm:p-8">
              <p className="text-xs font-semibold uppercase tracking-[0.16em] text-rose-600">Connection failed</p>
              <h2 className="mt-3 text-3xl font-semibold tracking-tight text-zinc-950">This link needs attention.</h2>
              <p className="mt-4 text-sm leading-6 text-zinc-600">
                {error || "Tortoise could not prepare extension setup."}
              </p>
            </section>
          )}
        </div>
      </section>
    </main>
  );
}
