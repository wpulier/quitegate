export const metadata = {
  title: "Data Use | QuietGate",
  description: "QuietGate Chrome extension data use and permission disclosure.",
};

const permissions = [
  {
    name: "Host access for X, Reddit, YouTube, Instagram, and QuietGate",
    reason:
      "QuietGate needs scoped host access to inject local tuning scripts, hide configured surfaces, and connect the extension to your QuietGate account.",
  },
  {
    name: "Declarative Net Request",
    reason:
      "QuietGate uses packaged DNR rules to block adult domains and site-specific media requests without sending browsing traffic to a remote service.",
  },
  {
    name: "Scripting",
    reason:
      "QuietGate uses scripting to refresh tuners in already-open tabs after policy changes and to run the optional all-site classifier only after you grant that permission.",
  },
  {
    name: "Storage",
    reason:
      "QuietGate stores local policy cache, extension device token, sync state, and local signed-out adult blocking preference.",
  },
  {
    name: "Alarms",
    reason:
      "QuietGate syncs policy periodically so browser protection stays current while Chrome is open.",
  },
  {
    name: "Optional all-site access",
    reason:
      "Optional broad access lets the local classifier detect missed adult websites outside the packaged domain list. It is not required for X, Reddit, YouTube, Instagram, or packaged adult-domain blocking.",
  },
];

export default function DataUsePage() {
  return (
    <main className="bg-zinc-50">
      <section className="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-4xl flex-col gap-8 px-6 py-16">
        <div>
          <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Chrome extension
          </p>
          <h1 className="text-4xl font-semibold tracking-tight text-zinc-950">
            QuietGate Data Use
          </h1>
          <p className="mt-4 text-lg leading-8 text-zinc-600">
            QuietGate has a single purpose: block distracting and adult content
            according to the policy you configure and sync across your devices.
          </p>
        </div>

        <div className="grid gap-4">
          {permissions.map((permission) => (
            <section
              className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm"
              key={permission.name}
            >
              <h2 className="text-lg font-semibold text-zinc-950">
                {permission.name}
              </h2>
              <p className="mt-2 text-sm leading-7 text-zinc-700">
                {permission.reason}
              </p>
            </section>
          ))}
        </div>
      </section>
    </main>
  );
}
