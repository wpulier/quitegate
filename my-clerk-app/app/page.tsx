import Link from "next/link";
import { publicDownloadPath } from "@/lib/launch-config";

const quietRows = ["YouTube", "Reddit", "Instagram", "X"];

const surfaceTabs = [
  { label: "YouTube", active: true },
  { label: "Reddit", active: false },
  { label: "Instagram", active: false },
  { label: "X", active: false },
];

const youtubeTuners = [
  { label: "Shorts shelf", value: "removed", active: true },
  { label: "Home feed", value: "quiet", active: true },
  { label: "Recommendations", value: "softened", active: true },
  { label: "Comments", value: "visible", active: false },
];

const crossSiteTuners = [
  { site: "YouTube", rule: "Hide Shorts, keep search and watch pages" },
  { site: "Reddit", rule: "Remove Popular, blur media, reduce NSFW pulls" },
  { site: "Instagram", rule: "Block Reels and Explore, keep messages usable" },
  { site: "X", rule: "Reduce media and trends, keep direct links readable" },
];

const feedRows = [
  { label: "Shorts shelf", state: "gone", tone: "rose" },
  { label: "Suggested videos", state: "softened", tone: "amber" },
  { label: "Creator comments", state: "kept", tone: "blue" },
];

const tuningPills = [
  "hide shorts",
  "quiet home",
  "soften recs",
  "keep search",
  "track time",
  "sync rules",
];

export default function Home() {
  const iosPath = publicDownloadPath("ios");

  return (
    <main className="overflow-x-hidden bg-[#fbfbef] text-zinc-950">
      <section className="mx-auto flex min-h-[78vh] w-full max-w-7xl flex-col items-center justify-center px-5 py-20 text-center sm:px-6">
        <div className="min-w-0 max-w-5xl">
          <h1 className="max-w-full text-[clamp(3.5rem,12vw,10rem)] font-semibold leading-[0.9] tracking-normal text-zinc-950 [text-wrap:balance]">
            Tortoise.
            <span className="block text-zinc-500">Tune your digital life.</span>
          </h1>
          <p className="mx-auto mt-7 max-w-xl text-base font-medium leading-7 text-zinc-600 sm:text-lg sm:leading-8">
            One account to manage your digital life across Mac, iPhone, and
            browser. Download Tortoise, sign in, and choose what gets quieted.
          </p>

          <div className="mx-auto mt-8 flex w-full flex-col items-center justify-center gap-3 sm:max-w-none sm:flex-row">
            <Link
              className="inline-flex min-h-12 w-[17rem] max-w-full items-center justify-center rounded-lg border-2 border-zinc-950 bg-zinc-950 px-6 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-zinc-950 focus:ring-offset-2 sm:w-auto"
              href={publicDownloadPath("mac")}
            >
              Download for Mac
            </Link>
            <Link
              className="inline-flex min-h-12 w-[17rem] max-w-full items-center justify-center rounded-lg border border-zinc-300 bg-white px-6 text-sm font-semibold text-zinc-900 shadow-sm transition hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-zinc-950 focus:ring-offset-2 sm:w-auto"
              href={iosPath}
            >
              Install on iPhone
            </Link>
          </div>

          <div className="mx-auto mt-8 flex max-w-[18rem] flex-wrap justify-center gap-2 sm:max-w-none">
            {quietRows.map((site) => (
              <span
                className="rounded-lg border border-zinc-200 bg-white/75 px-3 py-2 text-sm font-semibold text-zinc-800 shadow-sm"
                key={site}
              >
                {site}
              </span>
            ))}
          </div>
        </div>
      </section>

      <TuningConceptsSection />
    </main>
  );
}

function TuningConceptsSection() {
  return (
    <section
      aria-labelledby="tuning-concepts-title"
      className="border-y border-zinc-900 bg-[#101114] text-white"
    >
      <div className="mx-auto w-full max-w-7xl px-5 py-16 sm:px-6 sm:py-20">
        <div className="grid gap-7 lg:grid-cols-[0.74fr_1.26fr] lg:items-end">
          <div>
            <h2
              id="tuning-concepts-title"
              className="max-w-2xl text-4xl font-semibold leading-[1.02] tracking-normal text-white sm:text-6xl"
            >
              Tune the feed without breaking the internet.
            </h2>
            <p className="mt-5 max-w-xl text-base leading-7 text-white/58 sm:text-lg sm:leading-8">
              Tortoise removes the addictive surfaces and leaves the useful
              ones alone: search, messages, watch pages, links, and direct use.
            </p>
          </div>

          <div className="flex flex-wrap gap-2 lg:justify-end">
            {tuningPills.map((pill) => (
              <span
                className="rounded-full border border-white/12 bg-white/[0.06] px-3 py-2 text-xs font-semibold uppercase tracking-[0.08em] text-white/64"
                key={pill}
              >
                {pill}
              </span>
            ))}
          </div>
        </div>

        <div className="mt-10 grid gap-4 xl:grid-cols-[1.42fr_0.58fr]">
          <TuningStudio />
          <div className="grid gap-4">
            <HoverTimeConcept />
            <RuleDialConcept />
          </div>
          <CrossSiteConcept />
        </div>
      </div>
    </section>
  );
}

function TuningStudio() {
  return (
    <section
      aria-label="Tortoise tuning concept"
      className="overflow-hidden rounded-xl border border-white/12 bg-[#ededdf] text-zinc-950 shadow-[0_34px_110px_rgba(0,0,0,0.4)]"
    >
      <div className="flex min-h-12 items-center gap-3 border-b border-zinc-950/10 bg-white/85 px-4">
        <span className="h-3 w-3 rounded-full bg-[#ff5f57]" aria-hidden="true" />
        <span className="h-3 w-3 rounded-full bg-[#febc2e]" aria-hidden="true" />
        <span className="h-3 w-3 rounded-full bg-[#0f6fff]" aria-hidden="true" />
        <div className="ml-2 min-w-0 flex-1 rounded-lg border border-zinc-200 bg-white px-3 py-1.5 text-xs font-semibold text-zinc-500">
          youtube.com/watch
        </div>
        <span className="rounded-full bg-zinc-950 px-3 py-1 text-xs font-semibold text-white">
          tuned
        </span>
      </div>

      <div className="grid lg:grid-cols-[13rem_1fr]">
        <aside className="border-b border-zinc-950/10 bg-[#f8f8ef] p-4 lg:border-b-0 lg:border-r">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-zinc-500">
            Surfaces
          </p>
          <div className="mt-4 grid gap-2">
            {surfaceTabs.map((tab) => (
              <div
                className={`flex min-h-11 items-center justify-between rounded-lg border px-3 text-sm font-semibold ${
                  tab.active
                    ? "border-zinc-950 bg-zinc-950 text-white"
                    : "border-zinc-200 bg-white text-zinc-500"
                }`}
                key={tab.label}
              >
                <span>{tab.label}</span>
                <span
                  className={`h-2.5 w-2.5 rounded-full ${
                    tab.active ? "bg-[#0f6fff]" : "bg-zinc-300"
                  }`}
                />
              </div>
            ))}
          </div>

          <div className="mt-5 rounded-lg border border-zinc-200 bg-white p-3">
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-zinc-400">
              Today
            </p>
            <div className="mt-3 flex items-end justify-between gap-3">
              <div>
                <p className="text-3xl font-semibold leading-none">42m</p>
                <p className="mt-1 text-xs font-semibold text-zinc-500">
                  youtube.com
                </p>
              </div>
              <span className="rounded-full bg-[#eaf1ff] px-2.5 py-1 text-xs font-semibold text-[#0f4fb8]">
                focus
              </span>
            </div>
          </div>
        </aside>

        <div className="p-4 sm:p-5">
          <div className="grid gap-4 lg:grid-cols-[0.98fr_1.02fr]">
            <BeforeFeed />
            <AfterFeed />
          </div>
          <div className="mt-4 grid gap-4 lg:grid-cols-[1.03fr_0.97fr]">
            <TunerControlPanel />
            <TunedOutcomePanel />
          </div>
        </div>
      </div>
    </section>
  );
}

function BeforeFeed() {
  return (
    <article className="rounded-lg border border-zinc-200 bg-white p-3 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-zinc-400">
          Before
        </p>
        <span className="rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-500">
          default feed
        </span>
      </div>
      <div className="mt-3 aspect-video rounded-lg bg-zinc-950 p-3">
        <div className="flex h-full flex-col justify-between rounded-md border border-white/10 bg-white/[0.05] p-3">
          <div>
            <div className="h-3 w-3/4 rounded-full bg-white/30" />
            <div className="mt-3 h-2 w-1/2 rounded-full bg-white/14" />
          </div>
          <div className="grid grid-cols-4 gap-2">
            {Array.from({ length: 8 }).map((_, index) => (
              <span
                className="h-10 rounded-md bg-white/10"
                key={`before-tile-${index}`}
              />
            ))}
          </div>
        </div>
      </div>
      <div className="mt-3 grid gap-2">
        {["Shorts shelf", "Recommended videos", "Autoplay rail"].map((row) => (
          <div
            className="rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2"
            key={row}
          >
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold text-zinc-800">{row}</p>
              <p className="text-xs font-semibold text-zinc-400">visible</p>
            </div>
            <div className="mt-2 flex gap-1.5" aria-hidden="true">
              <span className="h-1.5 w-16 rounded-full bg-zinc-300" />
              <span className="h-1.5 w-10 rounded-full bg-zinc-200" />
              <span className="h-1.5 w-7 rounded-full bg-zinc-200" />
            </div>
          </div>
        ))}
      </div>
    </article>
  );
}

function AfterFeed() {
  return (
    <article className="rounded-lg border border-zinc-950 bg-zinc-950 p-3 text-white shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-white/45">
          After
        </p>
        <span className="rounded-full bg-[#0f6fff] px-2.5 py-1 text-xs font-semibold text-white">
          quieted
        </span>
      </div>
      <div className="mt-3 aspect-video rounded-lg bg-white/[0.06] p-3">
        <div className="flex h-full flex-col justify-between rounded-md border border-white/10 bg-zinc-950/70 p-3">
          <div>
            <div className="h-3 w-2/3 rounded-full bg-white/34" />
            <div className="mt-3 h-2 w-1/3 rounded-full bg-white/14" />
          </div>
          <div className="rounded-lg border border-white/10 bg-white/[0.06] p-3">
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold">Watch page stays useful</p>
              <span className="rounded-full bg-white px-2 py-1 text-xs font-semibold text-zinc-950">
                kept
              </span>
            </div>
          </div>
        </div>
      </div>
      <div className="mt-3 grid gap-2">
        {feedRows.map((row) => (
          <FeedStateRow key={row.label} {...row} />
        ))}
      </div>
    </article>
  );
}

function FeedStateRow({
  label,
  state,
  tone,
}: {
  label: string;
  state: string;
  tone: string;
}) {
  const toneClass =
    tone === "rose"
      ? "bg-[#ffe9ea] text-[#a52835]"
      : tone === "amber"
        ? "bg-[#fff4cc] text-[#7a4b00]"
        : "bg-[#eaf1ff] text-[#0f4fb8]";

  return (
    <div className="rounded-lg bg-white/[0.06] px-3 py-2">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm font-semibold text-white/88">{label}</p>
        <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${toneClass}`}>
          {state}
        </span>
      </div>
    </div>
  );
}

function TunerControlPanel() {
  return (
    <section className="rounded-lg border border-zinc-200 bg-white p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-zinc-950">Tuning controls</p>
          <p className="mt-1 text-xs font-medium text-zinc-500">
            Pick what disappears, softens, or stays visible.
          </p>
        </div>
        <span className="rounded-full bg-[#eaf1ff] px-3 py-1 text-xs font-semibold text-[#0f4fb8]">
          YouTube
        </span>
      </div>
      <div className="mt-4 space-y-2">
        {youtubeTuners.map((row) => (
          <div
            className="grid grid-cols-[1fr_auto_auto] items-center gap-3 rounded-lg border border-zinc-200 bg-[#fbfbef] px-3 py-2"
            key={row.label}
          >
            <p className="text-sm font-semibold text-zinc-950">{row.label}</p>
            <p className="text-xs font-semibold text-zinc-500">{row.value}</p>
            <span
              className={`relative h-6 w-10 rounded-full ${
                row.active ? "bg-[#0f6fff]" : "bg-zinc-300"
              }`}
              aria-label={row.active ? "Enabled" : "Disabled"}
            >
              <span
                className={`absolute top-1 h-4 w-4 rounded-full bg-white ${
                  row.active ? "right-1" : "left-1"
                }`}
              />
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}

function TunedOutcomePanel() {
  return (
    <section className="rounded-lg border border-zinc-200 bg-white p-4">
      <p className="text-sm font-semibold text-zinc-950">What remains</p>
      <div className="mt-4 grid grid-cols-2 gap-2">
        {["Search", "Subscriptions", "Watch page", "History"].map((row) => (
          <div
            className="rounded-lg border border-zinc-200 bg-[#fbfbef] px-3 py-3 text-sm font-semibold text-zinc-950"
            key={row}
          >
            {row}
          </div>
        ))}
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2">
        {["Shorts", "Home feed", "Trends", "Explore"].map((row) => (
          <div
            className="rounded-lg border border-dashed border-zinc-300 bg-zinc-100 px-3 py-3 text-sm font-semibold text-zinc-400 line-through"
            key={row}
          >
            {row}
          </div>
        ))}
      </div>
    </section>
  );
}

function HoverTimeConcept() {
  return (
    <section className="rounded-xl border border-white/12 bg-white p-5 text-zinc-950 shadow-[0_24px_80px_rgba(0,0,0,0.26)]">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-zinc-500">Hover entity</p>
          <h3 className="mt-1 text-2xl font-semibold">Total time stays visible</h3>
        </div>
        <span className="rounded-full bg-zinc-950 px-3 py-1 text-xs font-semibold text-white">
          live
        </span>
      </div>

      <div className="relative mt-5 aspect-[1.25] overflow-hidden rounded-lg bg-zinc-950 p-4 text-white">
        <div className="absolute left-4 top-4 h-3 w-24 rounded-full bg-white/24" />
        <div className="absolute left-4 top-10 h-2 w-16 rounded-full bg-white/12" />
        <div className="absolute bottom-4 left-4 right-4 h-2 rounded-full bg-white/14">
          <span className="block h-full w-[38%] rounded-full bg-[#0f6fff]" />
        </div>
        <div className="absolute right-4 top-4 w-40 rounded-lg border border-white/14 bg-white px-3 py-3 text-zinc-950 shadow-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-zinc-400">
            youtube.com
          </p>
          <p className="mt-1 text-2xl font-semibold leading-none">42m</p>
          <p className="mt-1 text-xs font-semibold text-zinc-500">today</p>
        </div>
      </div>
    </section>
  );
}

function RuleDialConcept() {
  return (
    <section className="rounded-xl border border-white/12 bg-[#17181c] p-5 text-white shadow-[0_24px_80px_rgba(0,0,0,0.26)]">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-white/50">Intensity</p>
          <h3 className="mt-1 text-2xl font-semibold">Focus without a lockout</h3>
        </div>
        <p className="text-4xl font-semibold leading-none">72</p>
      </div>

      <div className="mt-6 space-y-4">
        {[
          ["Useful", "Search, direct links, subscriptions", 88],
          ["Quieted", "Shorts, home, popular, trends", 72],
          ["Blocked", "Autoplay loops and reels", 54],
        ].map(([label, detail, value]) => (
          <div key={label}>
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-semibold">{label}</p>
                <p className="mt-1 text-xs text-white/45">{detail}</p>
              </div>
              <p className="text-sm font-semibold text-white/65">{value}%</p>
            </div>
            <div className="mt-2 h-2 overflow-hidden rounded-full bg-white/12">
              <span
                className="block h-full rounded-full bg-[#0f6fff]"
                style={{ width: `${value}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function CrossSiteConcept() {
  return (
    <section className="rounded-xl border border-white/12 bg-white/[0.06] p-5 shadow-[0_24px_90px_rgba(0,0,0,0.25)] xl:col-span-2">
      <div className="grid gap-5 lg:grid-cols-[0.54fr_1.46fr] lg:items-center">
        <div>
          <p className="text-sm font-semibold text-white/52">Concept library</p>
          <h3 className="mt-2 text-3xl font-semibold leading-tight text-white">
            Same idea, tuned for each feed.
          </h3>
          <p className="mt-3 text-sm leading-6 text-white/52">
            Each surface gets its own controls, but the mental model stays the
            same: keep the utility, remove the hooks.
          </p>
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          {crossSiteTuners.map((row) => (
            <div
              className="rounded-lg border border-white/12 bg-white p-4 text-zinc-950"
              key={row.site}
            >
              <div className="flex items-center justify-between gap-3">
                <p className="text-base font-semibold">{row.site}</p>
                <span className="h-2.5 w-2.5 rounded-full bg-[#0f6fff]" />
              </div>
              <p className="mt-3 text-sm leading-6 text-zinc-600">{row.rule}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
