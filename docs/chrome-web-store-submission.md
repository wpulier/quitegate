# Chrome Web Store Submission Text

Use these values when the Chrome Web Store dashboard asks for listing and
privacy-practices details for the production extension package.

## Store Listing

### Detailed Description

QuietGate helps you tune distracting websites and reduce exposure to adult
content. It applies the focus and adult-content rules you configure in
QuietGate across supported sites, including YouTube, X/Twitter, Instagram, and
Reddit.

Depending on your QuietGate policy, the extension can hide YouTube Home,
Shorts, recommendations, comments, live chat, autoplay, and daily-limit
overlays; hide X/Twitter sensitive media, videos, photos, media cards, trends,
and explicit search surfaces; hide Instagram Reels, Explore, suggested posts,
stories, messages, and notifications; and hide Reddit Popular/All, NSFW,
recommendation, media, and sidebar surfaces.

QuietGate can also block known adult domains using browser-native blocking
rules and a bundled adult-domain list. Optional all-sites access is requested
only when the user enables broader adult-domain protection or custom blocked
sites.

When signed in, the extension periodically syncs the user's QuietGate policy
from QuietGate. It stores only the settings and local usage counters needed to
apply that policy in the browser.

### Single Purpose

QuietGate applies user-configured focus and adult-content blocking rules across
supported websites.

## Privacy Practices

### Permission Justifications

#### activeTab

Used by the popup to identify the currently selected website so the user can
report or block that site from the extension UI.

#### alarms

Used to periodically sync the user's QuietGate policy so blocking and focus
rules stay up to date without requiring the user to reopen the popup.

#### declarativeNetRequest

Used to apply browser-native blocking rules for known adult domains and
user-configured blocked domains without reading or modifying page contents.

#### Host Permission Use

Required host permissions are limited to the supported sites that QuietGate
tunes: YouTube, X/Twitter, Instagram, Reddit, and QuietGate connection pages.
Optional all-sites access is requested only when the user enables broader
adult-domain protection or custom blocked sites, so the extension can block
matching adult or user-specified domains wherever they appear.

#### Remote Code Use

Answer "No" if the dashboard asks whether the extension uses remote code.

If a text field is still shown, use:

QuietGate does not execute remote JavaScript or load remote script files. All
executable code is bundled in the submitted extension package. The extension
only contacts QuietGate APIs to fetch user policy, report extension health, and
sync usage summaries when the user is signed in.

#### scripting

Used to inject bundled QuietGate content scripts and CSS into supported open
tabs after policy changes, browser startup, or extension updates so the current
page reflects the user's latest settings without requiring a reload.

#### storage

Used to store the user's QuietGate mode, feature settings, blocked-domain
state, browser connection token, sync status, and local usage counters needed to
apply policy inside the browser.

### Data Usage Certification

Before submitting, certify in the dashboard that the extension's data usage
complies with the Chrome Web Store Developer Program Policies.
