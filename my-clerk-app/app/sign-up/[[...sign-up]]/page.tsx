import Link from "next/link";
import { SignUp } from "@clerk/nextjs";

export default function SignUpPage() {
  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto grid w-full max-w-5xl gap-8 px-6 py-14 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
        <div>
          <p className="text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Start here
          </p>
          <h1 className="mt-3 text-4xl font-semibold tracking-tight text-zinc-950">
            Create your Tortoise account.
          </h1>
          <p className="mt-4 text-sm leading-6 text-zinc-600">
            After signup, Tortoise takes you straight to the setup checklist so
            Mac and iPhone end up connected to the same policy.
          </p>
          <Link
            className="mt-6 inline-flex text-sm font-semibold text-zinc-950 underline decoration-zinc-300 underline-offset-4"
            href="/"
          >
            Back to Tortoise
          </Link>
        </div>
        <div className="flex justify-center">
          <SignUp
            fallbackRedirectUrl="/setup"
            forceRedirectUrl="/setup"
            path="/sign-up"
            routing="path"
            signInUrl="/sign-in"
          />
        </div>
      </section>
    </main>
  );
}
