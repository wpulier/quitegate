import Link from "next/link";
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto grid w-full max-w-5xl gap-8 px-6 py-14 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
        <div>
          <p className="text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Welcome back
          </p>
          <h1 className="mt-3 text-4xl font-semibold tracking-tight text-zinc-950">
            Sign in and continue setup.
          </h1>
          <p className="mt-4 text-sm leading-6 text-zinc-600">
            Your Tortoise account keeps Mac, iPhone, browser tuning, and usage
            status together.
          </p>
          <Link
            className="mt-6 inline-flex text-sm font-semibold text-zinc-950 underline decoration-zinc-300 underline-offset-4"
            href="/"
          >
            Back to Tortoise
          </Link>
        </div>
        <div className="flex justify-center">
          <SignIn
            fallbackRedirectUrl="/setup"
            forceRedirectUrl="/setup"
            path="/sign-in"
            routing="path"
            signUpUrl="/sign-up"
          />
        </div>
      </section>
    </main>
  );
}
