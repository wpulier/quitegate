export const metadata = {
  title: "Support | QuietGate",
  description: "Get support for QuietGate.",
};

export default function SupportPage() {
  return (
    <main className="bg-zinc-50">
      <section className="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-4xl flex-col gap-8 px-6 py-16">
        <div>
          <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Support
          </p>
          <h1 className="text-4xl font-semibold tracking-tight text-zinc-950">
            QuietGate Support
          </h1>
          <p className="mt-4 text-lg leading-8 text-zinc-600">
            For setup help, false positives, missed adult sites, account
            deletion, or billing questions, contact the QuietGate team.
          </p>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-xl font-semibold text-zinc-950">Contact</h2>
          <p className="mt-3 text-sm leading-7 text-zinc-700">
            Email{" "}
            <a
              className="font-medium text-zinc-950 underline"
              href="mailto:wildstudiodeveloper@proton.me"
            >
              wildstudiodeveloper@proton.me
            </a>
            . Include your browser, device, extension version, and a short
            description of what happened.
          </p>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-xl font-semibold text-zinc-950">
            Common checks
          </h2>
          <ul className="mt-3 list-disc space-y-2 pl-5 text-sm leading-7 text-zinc-700">
            <li>Make sure you are signed in through the extension popup.</li>
            <li>Press Sync in the popup after changing policy on the dashboard.</li>
            <li>
              Enable Allow in Incognito on chrome://extensions if you want
              private-window protection.
            </li>
            <li>
              Grant full web protection only if you want local classification on
              websites outside packaged domain rules.
            </li>
          </ul>
        </div>
      </section>
    </main>
  );
}
