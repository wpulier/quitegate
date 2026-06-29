# QuietGate Tuner

Unpacked Firefox extension for tuned access:

- Focus mode blocks adult-domain pages and high-confidence explicit web pages,
  hides YouTube Home and Shorts, tracks YouTube time and watched videos,
  hides sensitive media and video/GIF players on X, Instagram
  Reels/Explore/suggested posts/stories, and Reddit Popular/All plus
  recommendations.
- Strict mode also hides comments, recommendations, distracting search modules,
  end screens, live chat, autoplay, playlist panels, tweet photos, rich media
  cards, X Explore/Trend surfaces, and Reddit media/sidebars,
  and enforces the configured daily YouTube time limit.
- Open mode keeps the hard blocker off, and can still use any custom site
  tuning rules selected in the Mac app.
- Connected browsers keep the last applied browser rules without polling. The
  Mac app tries to refresh connected Chromium browsers when settings change; use
  Refresh Browser only if a page has not updated.

The content scripts reapply tuning across YouTube, X, Instagram, and Reddit single-page navigation,
redirect direct Shorts URLs back to YouTube Home when Shorts are disabled, turn
autoplay off when YouTube exposes the autoplay control, and hide selected media
and discovery surfaces locally. When usage tracking is on, YouTube pages show a
small QuietGate usage pill and report daily time/video counts back to the Mac
app; when the daily limit is on and reached, the page pauses playback and shows
a limit overlay.

General-web adult blocking uses generated DNS blocklist snapshots in
`rules/adult-domains.json`. Firefox loads the snapshot through `webRequest` and
redirects adult pages while canceling adult-host subresources. Ordinary web
pages also receive `content/web-classifier.js`, which blocks only known adult
domains or high-confidence explicit page signals; it does not use AI image
scanning. The popup can report/block the current site when a miss is found.

## Load In A Supported Browser

1. Open QuietGate and go to Tuning.
2. Click Open Extensions.
3. Open Firefox add-on debugging.
4. Click Prepare in QuietGate.
5. Click Load unpacked in the browser and paste or select the copied folder path.
6. Click Install Sync in QuietGate.
7. Click Recheck in QuietGate to confirm the browser has the extension loaded.

When running from a source checkout, the shown folder is this
`FirefoxExtension` directory. When running from a built app, QuietGate reveals
the bundled copy inside the app.

The extension popup shows whether the browser is managed by the QuietGate Mac app.
When native sync is working, popup controls are read-only so the Mac app remains
the source of truth. Before native sync is installed, the popup remains a manual
fallback for testing the tuner.

## Native Sync

QuietGate writes the current mode to:

`~/Library/Application Support/QuietGate/extension-settings.json`

Click Install Sync in QuietGate's Tuning view to register the native messaging
host for this extension ID:

`quietgate@willpulier.com`

After that, opening YouTube, X, Instagram, Reddit, a blocked-domain page, the
connect page, or the extension popup asks the native host for the latest
QuietGate mode and stores it in browser extension storage. QuietGate does not
poll in the background; saved changes apply when the browser opens, a page
reloads, or the Mac app opens the connect page once.
