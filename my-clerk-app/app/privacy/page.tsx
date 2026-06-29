export const metadata = {
  title: "Privacy Policy | QuietGate",
  description: "QuietGate privacy policy for account sync and browser protection.",
};

export default function PrivacyPage() {
  return (
    <main className="bg-zinc-50">
      <section className="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-4xl flex-col gap-8 px-6 py-16">
        <div>
          <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Privacy
          </p>
          <h1 className="text-4xl font-semibold tracking-tight text-zinc-950">
            QuietGate Privacy Policy
          </h1>
          <p className="mt-4 text-sm text-zinc-500">Effective June 16, 2026</p>
        </div>

        <div className="space-y-6 rounded-lg border border-zinc-200 bg-white p-6 text-sm leading-7 text-zinc-700 shadow-sm">
          <section>
            <h2 className="text-xl font-semibold text-zinc-950">
              What QuietGate does
            </h2>
            <p className="mt-2">
              QuietGate blocks distracting and adult content according to the
              policy you configure. The Chrome extension enforces packaged site
              tuners, packaged adult-domain rules, and optional local page
              classification when you grant broad site access.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-zinc-950">
              Data we store
            </h2>
            <p className="mt-2">
              QuietGate stores your account identifier, email address, policy
              settings, registered device records, device health reports,
              extension version, script versions, ruleset status, sync times,
              enabled permission state, and recent block counters.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-zinc-950">
              Browser data
            </h2>
            <p className="mt-2">
              QuietGate does not sell browsing data. Site content is inspected
              locally only to enforce blocking rules. Device health may report
              aggregate protection status, such as whether adult blocking is
              enabled or how many rules are active. User-reported missed adult
              sites may include the reported domain and URL.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-zinc-950">
              Account and sync
            </h2>
            <p className="mt-2">
              Clerk provides account authentication. Supabase stores QuietGate
              user records, policies, devices, and device health snapshots. The
              Chrome extension stores a device-scoped token locally so it can
              read policy and post health without storing your Clerk session in
              content scripts.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-zinc-950">
              Deletion and support
            </h2>
            <p className="mt-2">
              You can revoke devices from the app or dashboard. For account
              deletion, data export, or support, email
              wildstudiodeveloper@proton.me.
            </p>
          </section>
        </div>
      </section>
    </main>
  );
}
