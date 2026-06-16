# General Web Adult Blocking Hardening

QuietGate now treats general-web adult blocking as a layered system instead of a short hand-maintained domain list.

## Layers

1. **Generated adult domain snapshot**
   - `script/generate_adult_blocklist.js` pulls maintained public DNS blocklists and ranks normalized domains.
   - The Swift app keeps a compact seed list in `AdultContentPreset.swift` for UI/counts and legacy paths.
   - Browser helpers receive a compact `blockedCategories: ["adultContent"]` signal so settings sync does not carry hundreds of thousands of domains.

2. **Chrome static DNR rules**
   - Chrome ships generated `rules/adult-static-*.json` rulesets.
   - Static rulesets redirect top-level adult pages to QuietGate and block adult-host subresources.
   - Dynamic DNR rules remain reserved for custom user domains and scoped X/Reddit media rules.

3. **Firefox webRequest rules**
   - Firefox loads `rules/adult-domains.json` and applies the same category-gated adult domain matching through `webRequest`.
   - Main-frame and sub-frame adult matches redirect to the QuietGate block page; subresources are canceled.

4. **General-web classifier**
   - `content/web-classifier.js` runs on ordinary web pages outside dedicated tuners.
   - It blocks only when a known adult domain matches or deterministic page signals cross a high-confidence threshold.
   - It does not use AI, OCR, image scanning, or remote moderation.

5. **Built-in controls**
   - Built-in Protections surfaces Apple Screen Time, Apple Sensitive Content Warning, Google SafeSearch, Chrome policies, Cloudflare Family DNS, CleanBrowsing, X, Reddit, and QuietGate tuner status separately.
   - These are additive controls; QuietGate still enforces dynamic browser blocking when platform labels miss content.

6. **Missed-site recovery**
   - The extension popup can block/report the current site.
   - The all-web interstitial includes an "Always block this site" action.
   - Reports are stored locally and pushed through native messaging when available.

## Precision Rules

- Do not block from weak text alone.
- Health, education, research, policy, and news contexts reduce classifier confidence unless there are strong adult domains or repeated explicit page signals.
- X and Reddit keep their dedicated tuners; the all-web classifier excludes those surfaces to avoid duplicate logic.
- Release checks must require the classifier and generated rule resources in both browser bundles.
