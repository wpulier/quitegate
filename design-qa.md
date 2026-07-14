**Comparison target**

- Source visual truth: `docs/design/extension-popup-tune-reference.jpeg`
- Collapsed implementation: `docs/design/extension-popup-collapsed.jpeg`
- Expanded implementation: `docs/design/extension-popup-youtube-expanded.jpeg`
- Signed-out implementation: `docs/design/extension-popup-signed-out.jpeg`
- Viewport: 380 CSS px-wide Chrome extension surface, captured inside the user's Chrome window
- State: signed in with Focus mode and synced tuning policy; all sites collapsed initially

**Full-view comparison evidence**

The popup carries over the Mac Tune screen's dark background, panel/elevated-panel hierarchy, blue selection treatment, green active state, platform tile structure, real YouTube/X/Instagram/Reddit marks, and system typography. The browser constraint intentionally changes the Mac app's single horizontal platform row into a 2x2 grid and omits device scope, add-app, and bulk-edit controls. The default browser state is intentionally different from the Mac reference: no site is selected until the user chooses one.

**Focused-region comparison evidence**

The platform picker and expanded YouTube panel were compared directly. Tile radii, hairlines, brand-mark containers, count hierarchy, cleanup panel, row separators, and green/gray switch states follow the Mac components at popup scale. The expanded settings list is constrained to an internal 286px scroll region so the extension never returns to the full-page checklist shown in the original bug report.

**Findings**

- No actionable P0/P1/P2 mismatches remain.
- The smaller type and 2x2 site layout are expected adaptations for the 380px Chrome popup rather than fidelity drift.
- The popup presents synced settings as read-only because the account policy is managed by Tortoise; it does not imply that disabled local controls can override the synced policy.

**Interaction verification**

- Verified all four platform tiles start unselected and collapsed.
- Verified YouTube expands and exposes only YouTube settings.
- Verified selecting X closes YouTube and exposes only X settings.
- Verified the compact Connected account menu opens independently.
- Verified the signed-out state hides all tuner controls and shows only account connection.
- Verified popup JavaScript syntax and the Chrome Store package checks.

**Comparison history**

- Initial render: the preview stylesheet path was incorrect, so the page rendered unstyled. Fixed the local preview path and captured the styled implementation again.
- Post-fix render: the compact signed-in, expanded, account, and signed-out states rendered correctly with no remaining P0/P1/P2 issues.

**Follow-up polish**

- P3: Consider adding a native Tortoise deep link later so “Managed by your Tortoise account” can open the Mac Tune screen directly.

final result: passed
