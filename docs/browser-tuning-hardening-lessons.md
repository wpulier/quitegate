# Browser Tuning Hardening Lessons

## Incident Summary

QuietGate looked connected because broad X media toggles such as "Hide Videos and GIFs" worked, but sensitive-media blocking still leaked unlabeled explicit content. The original precise path depended on X metadata such as sensitive-media labels, which misses unlabeled posts. The first stronger fallback blocked a media-dense X profile, but it was too broad: a normal media-heavy account such as `x.com/spencerpratt` could be caught even when the content was political or civic rather than explicit.

The final lesson is that a blocker needs both coverage and orientation. A broad signal like "many media posts" can help identify a profile shape, but it must not be the reason by itself. Explicit blocking needs explicit evidence: platform metadata, adult domains, or high-confidence adult account/post text. Political content should be handled by a separate default-off topic, not by sensitive-media or explicit-content logic.

## Version Freshness Lessons

- App freshness, bundled extension freshness, loaded extension freshness, service-worker freshness, content-script freshness, and live-page tuner freshness are different states.
- A top-level "Newest version" app indicator does not prove Chrome is executing the newest content script.
- Browser helper status must report manifest version, script versions, settings version, profile identity, and platform-control readback separately.
- Fix acceptance must inspect the exact live URL that failed, not only a nearby route.

## Dynamic App Lessons

- SPA routes must be tested as route families, not one URL. For X profiles, root, Replies, Media, Highlights, and Articles are separate paths with the same blocking intent.
- Fallback/rescue injection must stay behaviorally aligned with static content scripts.
- Session-scoped classification can prevent flicker while navigating within one profile, but the classification key must be specific to the account/community handle.
- Open mode and feature changes must remove managed classes, placeholders, counters, and stale session assumptions.

## Precision Rules

- Sensitive/labeled blocking uses platform metadata and visible sensitive-media warnings.
- Explicit/unlabeled blocking requires adult-domain or high-confidence adult text/account cues, and keyword cues should remain scoped to media-bearing posts or profile surfaces.
- X explicit hashtags often arrive as concatenated cue words, such as `#ThroatPie`, so high-confidence compound hashtags need explicit coverage without relaxing the media-bearing-post guard.
- X Search Media is a separate grid-like surface: it may not expose normal tweet article text, so explicit search queries and broad photo/video/card toggles must be tested against `/search?...&f=media`.
- Media density alone is not an explicit signal.
- Politics, news, gambling, shopping, and other non-explicit topics should be separate default-off topic toggles with their own tests and wording.

## Acceptance Checklist

- The exact reported URL is covered by a deterministic fixture and, when possible, a live-browser check.
- A nearby false-positive URL is covered by a fixture before broadening any heuristic.
- Chrome static injection, Chrome dynamic injection, Chrome rescue injection, Firefox fallback, manifests, app bundle resources, packaging, and DMG verification all include the changed script.
- `settingsVersion` changes when user-facing tuning options change; tuner script versions change when content-script behavior changes.
- The app UI distinguishes platform controls, browser helper freshness, QuietGate tuner state, and app update state.
