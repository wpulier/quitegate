import Link from "next/link";
import type { ReactNode } from "react";

type AuthPageShellProps = {
  eyebrow: string;
  title: string;
  description: string;
  alternateHref: string;
  alternateLabel: string;
  children: ReactNode;
};

const accountBenefits = [
  {
    title: "One shared policy",
    detail: "Your browser, Mac, and iPhone use the same protection settings.",
  },
  {
    title: "Private by default",
    detail: "Tortoise syncs settings and health—not your browsing history.",
  },
  {
    title: "Pick up where you left off",
    detail: "After authentication, you return to the setup step you started.",
  },
];

export function AuthPageShell({
  eyebrow,
  title,
  description,
  alternateHref,
  alternateLabel,
  children,
}: AuthPageShellProps) {
  return (
    <main className="bg-[#fbfbef] px-5 py-10 sm:px-6 sm:py-14">
      <section className="mx-auto grid min-h-[calc(100vh-12rem)] w-full max-w-6xl overflow-hidden rounded-2xl border border-zinc-200/90 bg-white shadow-[0_24px_80px_rgba(24,24,27,0.10)] lg:grid-cols-[0.82fr_1.18fr]">
        <div className="flex flex-col justify-between bg-[#101114] p-7 text-white sm:p-10 lg:p-12">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#8ea6ff]">
              {eyebrow}
            </p>
            <h1 className="mt-4 max-w-lg text-4xl font-semibold leading-[1.02] tracking-tight sm:text-5xl">
              {title}
            </h1>
            <p className="mt-5 max-w-lg text-base leading-7 text-white/64">
              {description}
            </p>
          </div>

          <div className="mt-12 grid gap-5">
            {accountBenefits.map((benefit) => (
              <div className="border-t border-white/12 pt-4" key={benefit.title}>
                <p className="text-sm font-semibold text-white">{benefit.title}</p>
                <p className="mt-1 text-sm leading-6 text-white/55">{benefit.detail}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="flex min-w-0 flex-col items-center justify-center bg-[#f7f7f1] p-5 sm:p-10 lg:p-12">
          <div className="flex w-full max-w-md justify-end pb-5">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-3.5 py-2 text-sm font-semibold text-zinc-700 transition hover:border-zinc-400 hover:text-zinc-950 focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2"
              href={alternateHref}
            >
              {alternateLabel}
            </Link>
          </div>
          <div className="flex w-full max-w-md justify-center">{children}</div>
        </div>
      </section>
    </main>
  );
}
