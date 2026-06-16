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

  function collectSensitiveMetadata(payload) {
    const tweetIDs = new Set();
    const mediaURLs = new Set();
    const mediaIDs = new Set();
    const seen = new WeakSet();
    let visited = 0;

    function walk(value, ancestors) {
      if (!isObject(value) || seen.has(value) || visited > MAX_WALK_NODES) {
        return;
      }
      seen.add(value);
      visited += 1;

      if (hasSensitiveSignal(value)) {
        for (const id of contextTweetIDs(value, ancestors)) {
          tweetIDs.add(id);
        }
        collectMediaURLHints(value, mediaURLs);
        collectMediaIDs(value, mediaIDs);
      }

      const nextAncestors = ancestors.length >= 10
        ? [...ancestors.slice(1), value]
        : [...ancestors, value];
      for (const child of Object.values(value)) {
        walk(child, nextAncestors);
      }
    }

    walk(payload, []);
    return {
      tweetIDs: [...tweetIDs],
      mediaURLs: [...mediaURLs],
      mediaIDs: [...mediaIDs]
    };
  }

  function emitSensitiveMetadata(payload) {
    try {
      const metadata = collectSensitiveMetadata(payload);
      if (metadata.tweetIDs.length === 0 && metadata.mediaURLs.length === 0 && metadata.mediaIDs.length === 0) {
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
