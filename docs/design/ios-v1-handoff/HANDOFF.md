# Tortoise iOS — Redesign Handoff

Redesign of the four bottom-tab screens of the Tortoise iPhone app, plus a
stitched overview. These are high-fidelity, **interactive HTML mockups** built
to match the app's real design language (lifted from `Tortoise/ContentView.swift`)
— they are a spec and alignment artifact, **not** the shipping SwiftUI build.

Guiding thesis for the whole redesign: **one job per screen. Everything that
isn't that job folds away** (accordions, collapsible sections, self-hiding setup).

---

## Files

| File | What it is |
|------|------------|
| `Usage — Redesign.dc.html` | Usage tab (new first tab) |
| `Tune — Redesign.dc.html` | Tune tab |
| `Block — Redesign.dc.html` | Block tab |
| `Devices — Redesign.dc.html` | Devices tab (new last tab) |
| `All Screens.dc.html` | All four side-by-side on a pannable canvas |
| `*Redesign.dc.html` (no spaces) | ASCII-named copies the canvas imports; keep in sync with the originals |
| `support.js` | DC runtime (required to open any page) |
| `assets/*.svg` | Brand marks (YouTube, X, Instagram, Reddit) — from the app's asset catalog |

**To view:** open any `.dc.html` in a browser (they need `support.js` and
`assets/` alongside them, which this folder preserves). All pages are live —
tap accordions, mode cards, toggles, and folded sections.

---

## Design system (matches the app)

Colors (from `TortoiseDesign`):
- Background `#0e0e11` · Panel `#1e1e22` · Elevated `#28282d`
- Text: primary `#f6f6fa` · secondary `#9e9eaa` · tertiary `#787885`
- Hairline `rgba(255,255,255,.10)` · strong hairline `rgba(255,255,255,.15)`
- Accent (blue) `#3e63dd` · action blue `#0a84ff` · green `#30cc5c`
- Orange `#ff9500` · red `#ff3b30` · strict purple `#a855f7`

Type: system font (SF Pro). Screen title 32/700 · card title 15–17/700 ·
body 13–14 · caption 12 · section label 12/700 uppercase, tracked.
Cards: radius 16–18, padding 16–20, 1px strong-hairline border.
Switches: 44×26 track, 21px knob, green when on.

---

## Tab order & the setup prerequisite

Order is now **Usage → Tune → Block → Devices**. Usage leads because it's the
daily-use screen; Devices is "set once," so it's last.

The only thing that used to justify Devices-first was setup. That's now handled
without hijacking navigation: **while the setup checklist is incomplete, an
orange "Finish setting up this iPhone · 3 of 4" banner shows at the top of Usage**
(the landing screen), stating that blocking & tuning stay off until setup is done,
and linking to Devices. When setup completes, the banner disappears and Devices'
own setup card self-collapses to a single "This iPhone is all set" row.

---

## Page-by-page

### Usage — "How am I doing today?"
- **One dominant number** (today's total) with a green **↓ vs. yesterday** trend
  chip (down is framed as good) and a plain-English context line.
- **Week trend** as a slim 7-bar sparkline, today highlighted.
- **Web vs. iPhone** split as a small legend.
- **By app & site** (folded): a unified breakdown — named destinations (apps AND
  standout websites like `nytimes.com` that cross a ~15m threshold) plus a
  **browser catch-all** ("Safari · other sites") for everything below threshold.
  Each row carries **activity detail** — "42 videos watched", "~310 posts seen" —
  ported from the Mac floating-bar feature. Browser-sourced counts are exact;
  iPhone-side ones are tagged **· est.** to keep the honesty contract.
- **By account** (folded).

### Tune — "Augment apps, don't block them"
- A **segmented control** splits the two real surfaces:
  - **In the browser** — per-app accordions (YouTube/X/Instagram/Reddit) that hide
    feeds, Shorts, sensitive media, etc. Reshapes the *web* version in Safari +
    connected browsers. Icon-forward toggles with plain-English descriptions.
  - **Apps on iPhone** — installed native apps. States honestly that Apple won't
    let anything change what's *inside* an app, so the controls are what actually
    work: **per-app daily limit** (steppers) + a **Downtime** window.
- Accordion: one app open at a time; counts update live.

### Block — "What's off-limits right now?"
- Four picks, radio-style: **Open / Focus / Strict / Custom**. Only one active.
- **Each mode shows its contents at a glance** (icon strips) without selecting —
  Focus = Instagram/TikTok/adult; Strict = all apps+sites, purple "lockable" tag;
  Custom = a live count of your picked apps.
- **Custom** expands to a per-app on/off list (the "per app" path).
- **Timed session** ("Lock in for a set time") is folded at the bottom — optional.

### Devices — "Access & setup"
- **Account card** with one **Connections** row that reveals everything on the
  unified account (This iPhone, Mac, nested browser profiles) with status dots.
- **Setup** block: full checklist while incomplete; collapses to one green
  "This iPhone is all set" row when done (re-expandable).

---

## Open decisions for the team

1. **Native-app control lives in two places.** Tune has per-app *daily limits*;
   Block has *hard blocking* of apps (in Focus/Strict/Custom). Line drawn:
   Block = off-limits, Tune = soft allowance + downtime. Confirm this split or
   consolidate before engineering builds two mental models.
2. **Threshold for a site to appear on its own in Usage** is a ~15m placeholder —
   fixed value or a setting?
3. **Multiple browser catch-all rows?** Today Safari rolls up; a busy day could
   add "Chrome · other sites." Merge into one "Other browsing" line, or keep
   per-browser?

## Not yet designed (recommended before building against this)

- **Empty / zero states** (brand-new account, no usage yet).
- **Loading, offline / "catching up," and error states.**
- **Signed-out / first-run flow** — the on-ramp into the checklist.
- **Setup step screens** (Allow Screen Time / Choose apps / Verify Safari) — rows
  exist; the actual moments don't.
- **Locked-Strict-session UI** — the app should visibly refuse to weaken while a
  locked session is active. Core promise, not yet drawn.
- **Focus Windows / schedule** (auto-apply Focus/Strict on a daily schedule).
