"use client";

import Link from "next/link";
import { SignInButton, UserButton, useUser } from "@clerk/nextjs";

export function SiteAuthNav() {
  const { isLoaded, isSignedIn } = useUser();

  if (!isLoaded) {
    return <div className="h-9 w-16 rounded-md bg-zinc-100" aria-hidden="true" />;
  }

  return (
    <div className="flex items-center gap-3">
      {isSignedIn ? (
        <>
          <Link
            className="rounded-md px-3 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-100"
            href="/setup"
          >
            Setup
          </Link>
          <UserButton />
        </>
      ) : (
        <SignInButton fallbackRedirectUrl="/setup" forceRedirectUrl="/setup">
          <button className="rounded-md px-3 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-100">
            Sign in
          </button>
        </SignInButton>
      )}
    </div>
  );
}
