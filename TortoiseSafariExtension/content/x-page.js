(() => {
  if (window.__quietgateXSensitiveDetectorInstalled) {
    return;
  }
  window.__quietgateXSensitiveDetectorInstalled = true;

  const MESSAGE_SOURCE = "quietgate-x-page-detector";
  const MAX_WALK_NODES = 30000;
  const STATUS_ID_PATTERN = /(?:^|\/)(?:status|statuses)\/(\d{1,20})(?:[/?#]|$)/gi;
  const NUMERIC_ID_PATTERN = /^\d{1,20}$/;
  const MEDIA_KEY_PATTERN = /^(?:\d+_)?(\d{1,20})$/;
  const SENSITIVE_WORD_PATTERN = /sensitive|adult|graphic|violence|violent|nudity|nsfw|interstitial|warning/i;
  const SENSITIVE_CONTAINER_KEY_PATTERN = /blurred|interstitial|tombstone/i;
  const MEDIA_URL_KEYS = new Set([
    "media_url",
    "media_url_https",
    "preview_image_url",
    "url",
    "expanded_url"
  ]);
  const MEDIA_ID_KEYS = new Set([
    "id",
    "id_str",
    "media_id",
    "media_id_string",
    "mediaId",
    "mediaID",
    "media_key",
    "mediaKey",
    "media_keys",
    "mediaKeys"
  ]);

  function isObject(value) {
    return value !== null && typeof value === "object";
  }

  function addNumericID(ids, value) {
    const normalized = String(value || "").trim();
    if (NUMERIC_ID_PATTERN.test(normalized)) {
      ids.add(normalized);
    }
  }

  function addMediaID(ids, value) {
    if (Array.isArray(value)) {
      for (const child of value) {
        addMediaID(ids, child);
      }
      return;
    }

    if (isObject(value)) {
      for (const child of Object.values(value)) {
        addMediaID(ids, child);
      }
      return;
    }

    const normalized = String(value || "").trim();
    const match = normalized.match(MEDIA_KEY_PATTERN);
    if (match) {
      ids.add(match[1]);
    }
  }

  function addStatusIDsFromText(ids, value) {
    if (typeof value !== "string") {
      return;
    }

    STATUS_ID_PATTERN.lastIndex = 0;
    let match;
    while ((match = STATUS_ID_PATTERN.exec(value)) !== null) {
      ids.add(match[1]);
    }
  }

  function normalizedMediaURL(value) {
    if (typeof value !== "string" || !value) {
      return null;
    }

    try {
      const url = new URL(value, location.href);
      if (!/(^|\.)twimg\.com$/i.test(url.hostname)) {
        return null;
      }
      return `${url.hostname}${url.pathname}`;
    } catch (_error) {
      return null;
    }
  }

  function collectMediaURLHints(value, urls, seen = new WeakSet(), depth = 0) {
    if (!isObject(value) || seen.has(value) || depth > 5) {
      return;
    }
    seen.add(value);

    for (const [key, child] of Object.entries(value)) {
      if (MEDIA_URL_KEYS.has(key)) {
        const normalized = normalizedMediaURL(child);
        if (normalized) {
          urls.add(normalized);
        }
      }

      if (isObject(child)) {
        collectMediaURLHints(child, urls, seen, depth + 1);
      }
    }
  }

  function collectMediaIDs(value, ids, seen = new WeakSet(), depth = 0) {
    if (!isObject(value) || seen.has(value) || depth > 5) {
      return;
    }
    seen.add(value);

    for (const [key, child] of Object.entries(value)) {
      if (MEDIA_ID_KEYS.has(key)) {
        addMediaID(ids, child);
      }

      if (isObject(child)) {
        collectMediaIDs(child, ids, seen, depth + 1);
      }
    }
  }

  function collectTweetIDs(value, ids, seen = new WeakSet(), depth = 0) {
    if (!isObject(value) || seen.has(value) || depth > 5) {
      return;
    }
    seen.add(value);

    if (typeof value.rest_id === "string") {
      addNumericID(ids, value.rest_id);
    }
    if (isObject(value.legacy) && typeof value.legacy.id_str === "string") {
      addNumericID(ids, value.legacy.id_str);
    }
    if (looksLikeTweet(value) && typeof value.id === "string") {
      addNumericID(ids, value.id);
    }
    if (typeof value.id_str === "string" && (value.full_text || value.entities || value.extended_entities)) {
      addNumericID(ids, value.id_str);
    }

    for (const [key, child] of Object.entries(value)) {
      if (typeof child === "string") {
        if (/^(tweet|status).*(id)$/i.test(key) || /^(id_str|rest_id)$/i.test(key)) {
          addNumericID(ids, child);
        }
        addStatusIDsFromText(ids, child);
      } else if (isObject(child)) {
        collectTweetIDs(child, ids, seen, depth + 1);
      }
    }
  }

  function looksLikeTweet(value) {
    if (!isObject(value)) {
      return false;
    }
    return value.__typename === "Tweet" ||
      value.tweet_results ||
      value.tweet ||
      value.possibly_sensitive !== undefined ||
      (typeof value.id === "string" && (
        value.text !== undefined ||
        value.attachments !== undefined ||
        value.media_metadata !== undefined ||
        value.possibly_sensitive !== undefined
      )) ||
      value.legacy?.possibly_sensitive !== undefined ||
      (typeof value.rest_id === "string" && isObject(value.legacy) && (
        value.legacy.full_text !== undefined ||
        value.legacy.extended_entities !== undefined ||
        value.legacy.possibly_sensitive !== undefined
      ));
  }

  function contextTweetIDs(value, ancestors) {
    const ids = new Set();
    collectTweetIDs(value, ids);

    for (let index = ancestors.length - 1; index >= 0; index -= 1) {
      const ancestor = ancestors[index];
      if (looksLikeTweet(ancestor)) {
        collectTweetIDs(ancestor, ids);
        break;
      }
    }

    return ids;
  }

  function hasSensitiveWarningObject(value) {
    if (!isObject(value)) {
      return false;
    }

    for (const [key, child] of Object.entries(value)) {
      if (child === true && SENSITIVE_WORD_PATTERN.test(key)) {
        return true;
      }
      if (typeof child === "string" && SENSITIVE_WORD_PATTERN.test(child)) {
        return true;
      }
    }
    return false;
  }

  function hasTruthySensitiveField(value, seen = new WeakSet(), depth = 0) {
    if (typeof value === "string") {
      return SENSITIVE_WORD_PATTERN.test(value);
    }
    if (!isObject(value) || seen.has(value) || depth > 4) {
      return false;
    }
    seen.add(value);

    return Object.entries(value).some(([key, child]) => {
      if (child === true && SENSITIVE_WORD_PATTERN.test(key)) {
        return true;
      }
      if (typeof child === "string" && SENSITIVE_WORD_PATTERN.test(child)) {
        return true;
      }
      if (isObject(child) && SENSITIVE_CONTAINER_KEY_PATTERN.test(key) && Object.keys(child).length > 0) {
        return true;
      }
      return hasTruthySensitiveField(child, seen, depth + 1);
    });
  }

  function hasSensitiveSignal(value) {
    return value?.possibly_sensitive === true ||
      hasSensitiveWarningObject(value?.sensitive_media_warning) ||
      hasTruthySensitiveField(value?.mediaVisibilityResults);
  }

  const AUTHOR_HANDLE_PATTERN = /^[a-z0-9_]{1,15}$/;

  // Account-level cues, deliberately TIGHTER than x.js's per-post cue regex:
  // one bio match blocklists the whole account instantly, so only markers
  // that are near-certain adult-account signals belong here.
  const ACCOUNT_BIO_CUE = /(?:🔞|\b(?:nsfw|18\+|xxx|porn(?:hub|star|ography)?|onlyfans|only\s*fans|fansly|redgifs|adults?\s+only|explicit\s+content)\b)/i;
  const ACCOUNT_BIO_DOMAINS = [
    "onlyfans.com",
    "fansly.com",
    "redgifs.com",
    "pornhub.com",
    "xvideos.com",
    "xnxx.com",
    "xhamster.com",
    "redtube.com",
    "youporn.com",
    "spankbang.com",
    "stripchat.com",
    "chaturbate.com",
    "cam4.com",
    "manyvids.com",
    "erome.com",
    "fapello.com"
  ];

  function normalizedAuthorHandle(value) {
    const handle = String(value || "").trim().replace(/^@/, "").toLowerCase();
    return AUTHOR_HANDLE_PATTERN.test(handle) ? handle : null;
  }

  function collectBioStrings(value, parts, depth = 0) {
    if (!isObject(value) || depth > 4) {
      return;
    }
    for (const [key, child] of Object.entries(value)) {
      if (typeof child === "string" && /^(description|name|expanded_url|display_url|url)$/.test(key)) {
        parts.push(child);
      } else if (isObject(child)) {
        collectBioStrings(child, parts, depth + 1);
      }
    }
  }

  /// Adult-account check against everything the author object says about
  /// itself: bio text, display name, and pinned/bio link URLs.
  function authorBioIsExplicit(userResult) {
    if (!isObject(userResult)) {
      return false;
    }
    const parts = [];
    for (const source of [
      userResult.legacy?.description,
      userResult.profile_bio?.description,
      userResult.description,
      userResult.legacy?.name,
      userResult.core?.name,
      userResult.name
    ]) {
      if (typeof source === "string") {
        parts.push(source);
      }
    }
    collectBioStrings(userResult.legacy?.entities, parts);
    collectBioStrings(userResult.profile_bio?.entities, parts);

    const bioText = parts.join(" ").toLowerCase();
    if (!bioText) {
      return false;
    }
    return ACCOUNT_BIO_CUE.test(bioText) ||
      ACCOUNT_BIO_DOMAINS.some((domain) => bioText.includes(domain));
  }

  function authorUserResult(root) {
    const userResult =
      root?.core?.user_results?.result ||
      root?.user_results?.result ||
      root?.user ||
      root?.author;
    return isObject(userResult) ? userResult : null;
  }

  // The tweet's canonical author slot only — never entities.user_mentions or
  // quoted/retweeted subtrees, so mentioned and quoted users are not blamed
  // for someone else's sensitive post.
  function authorHandleForTweet(root) {
    const userResult = authorUserResult(root);
    if (!userResult) {
      return null;
    }
    return normalizedAuthorHandle(
      userResult.legacy?.screen_name ||
      userResult.core?.screen_name ||
      userResult.screen_name
    );
  }

  function rootTweetID(root) {
    for (const candidate of [root?.rest_id, root?.legacy?.id_str, root?.id_str, root?.id]) {
      const normalized = String(candidate || "").trim();
      if (NUMERIC_ID_PATTERN.test(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  function contextTweetRoot(value, ancestors) {
    for (let index = ancestors.length - 1; index >= 0; index -= 1) {
      if (looksLikeTweet(ancestors[index])) {
        return ancestors[index];
      }
    }
    return looksLikeTweet(value) ? value : null;
  }

  function collectSensitiveMetadata(payload) {
    const tweetIDs = new Set();
    const mediaURLs = new Set();
    const mediaIDs = new Set();
    const sensitiveAuthorPairs = new Map();
    const walkedTweetIDs = new Set();
    const adultBioTweetIDs = new Set();
    const seen = new WeakSet();
    let visited = 0;

    function walk(value, ancestors) {
      if (!isObject(value) || seen.has(value) || visited > MAX_WALK_NODES) {
        return;
      }
      seen.add(value);
      visited += 1;

      // Every tweet root the payload carries, sensitive or not — clean
      // verdicts (walked minus sensitive minus adult-bio-authored) are what
      // un-screen media in screen-until-verified mode. An adult bio is
      // account-level evidence: it convicts the author on their FIRST post,
      // no per-post strikes needed.
      if (looksLikeTweet(value)) {
        const walkedID = rootTweetID(value);
        if (walkedID) {
          walkedTweetIDs.add(walkedID);
          const userResult = authorUserResult(value);
          if (userResult && authorBioIsExplicit(userResult)) {
            adultBioTweetIDs.add(walkedID);
            const handle = authorHandleForTweet(value);
            if (handle) {
              sensitiveAuthorPairs.set(`${handle}:bio`, { handle, tweetID: walkedID, account: true });
            }
          }
        }
      }

      if (hasSensitiveSignal(value)) {
        for (const id of contextTweetIDs(value, ancestors)) {
          tweetIDs.add(id);
        }
        collectMediaURLHints(value, mediaURLs);
        collectMediaIDs(value, mediaIDs);

        const root = contextTweetRoot(value, ancestors);
        const handle = authorHandleForTweet(root);
        const tweetID = rootTweetID(root);
        if (handle && tweetID) {
          sensitiveAuthorPairs.set(`${handle}:${tweetID}`, { handle, tweetID });
        }
      }

      const nextAncestors = ancestors.length >= 10
        ? [...ancestors.slice(1), value]
        : [...ancestors, value];
      for (const child of Object.values(value)) {
        walk(child, nextAncestors);
      }
    }

    walk(payload, []);
    // Sensitive attribution can land on ids the tweet-root scan also saw;
    // sensitive always wins, so clean is walked minus sensitive minus
    // anything an adult-bio account posted.
    const cleanTweetIDs = [...walkedTweetIDs].filter(
      (id) => !tweetIDs.has(id) && !adultBioTweetIDs.has(id)
    );
    return {
      tweetIDs: [...tweetIDs],
      mediaURLs: [...mediaURLs],
      mediaIDs: [...mediaIDs],
      sensitiveAuthors: [...sensitiveAuthorPairs.values()],
      cleanTweetIDs
    };
  }

  function emitSensitiveMetadata(payload) {
    try {
      const metadata = collectSensitiveMetadata(payload);
      if (
        metadata.tweetIDs.length === 0 &&
        metadata.mediaURLs.length === 0 &&
        metadata.mediaIDs.length === 0 &&
        metadata.sensitiveAuthors.length === 0 &&
        metadata.cleanTweetIDs.length === 0
      ) {
        return;
      }
      window.postMessage({
        source: MESSAGE_SOURCE,
        type: "sensitive-media",
        ...metadata
      }, window.location.origin);
    } catch (_error) {
      // Keep X's own networking path untouched if payload inspection fails.
    }
  }

  function shouldInspectURL(value) {
    const url = String(value || "");
    return /\/graphql\/|\/i\/api\/|\/2\/tweets|UserMedia|TweetDetail|HomeTimeline|SearchTimeline|Adaptive/i.test(url);
  }

  function inspectResponse(response, fallbackURL) {
    try {
      const responseURL = response?.url || fallbackURL || "";
      if (!shouldInspectURL(responseURL)) {
        return;
      }
      response.clone().json().then(emitSensitiveMetadata).catch(() => {});
    } catch (_error) {
      // Non-JSON responses are expected on X.
    }
  }

  const originalFetch = window.fetch;
  if (typeof originalFetch === "function") {
    window.fetch = function quietGateFetch(input, init) {
      const fallbackURL = typeof input === "string" ? input : input?.url;
      return originalFetch.apply(this, arguments).then((response) => {
        inspectResponse(response, fallbackURL);
        return response;
      });
    };
  }

  const XHR = window.XMLHttpRequest;
  if (XHR?.prototype) {
    const originalOpen = XHR.prototype.open;
    const originalSend = XHR.prototype.send;

    XHR.prototype.open = function quietGateOpen(method, url) {
      this.__quietgateXURL = url;
      return originalOpen.apply(this, arguments);
    };

    XHR.prototype.send = function quietGateSend() {
      this.addEventListener("load", () => {
        try {
          const responseURL = this.responseURL || this.__quietgateXURL || "";
          if (!shouldInspectURL(responseURL) || typeof this.responseText !== "string") {
            return;
          }
          emitSensitiveMetadata(JSON.parse(this.responseText));
        } catch (_error) {
          // Ignore non-JSON and inaccessible XHR responses.
        }
      });
      return originalSend.apply(this, arguments);
    };
  }
})();
