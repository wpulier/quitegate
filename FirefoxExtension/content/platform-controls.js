(() => {
  const runtime = globalThis.browser?.runtime || globalThis.chrome?.runtime;
  if (!runtime?.sendMessage) {
    return;
  }

  const CHECKED_MARKER = "quietgatePlatformControls";
  let lastPayload = null;

  function text(node) {
    return String(node?.innerText || node?.textContent || "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function visibleText() {
    return text(document.body).toLowerCase();
  }

  function parseBooleanAttribute(value) {
    if (value === "true") {
      return true;
    }
    if (value === "false") {
      return false;
    }
    return null;
  }

  function controlState(control) {
    if (!control) {
      return null;
    }
    if (control.matches?.("input[type='checkbox']")) {
      return Boolean(control.checked);
    }
    for (const name of ["aria-checked", "data-checked", "checked"]) {
      const parsed = parseBooleanAttribute(control.getAttribute?.(name));
      if (parsed !== null) {
        return parsed;
      }
    }
    const input = control.querySelector?.("input[type='checkbox']");
    if (input) {
      return Boolean(input.checked);
    }
    return null;
  }

  function controlNearText(patterns) {
    const candidates = [
      ...document.querySelectorAll([
        "label",
        "[role='switch']",
        "[role='checkbox']",
        "button[aria-checked]",
        "input[type='checkbox']",
        "[data-testid]",
        "div",
        "span"
      ].join(","))
    ];

    for (const node of candidates) {
      const nodeText = [
        text(node),
        node.getAttribute?.("aria-label") || "",
        node.getAttribute?.("data-testid") || ""
      ].join(" ").toLowerCase();
      if (!patterns.some((pattern) => pattern.test(nodeText))) {
        continue;
      }

      const directState = controlState(node);
      if (directState !== null) {
        return directState;
      }

      const container = node.closest?.("label, [role='switch'], [role='checkbox'], button, div") || node;
      const nestedState = controlState(container);
      if (nestedState !== null) {
        return nestedState;
      }

      for (const sibling of [
        container.previousElementSibling,
        container.nextElementSibling,
        node.previousElementSibling,
        node.nextElementSibling
      ]) {
        const siblingState = controlState(sibling);
        if (siblingState !== null) {
          return siblingState;
        }
      }
    }
    return null;
  }

  function xSnapshot() {
    const path = location.pathname.toLowerCase();
    const pageText = visibleText();
    const isContentSettings =
      path.includes("/settings/content_you_see") ||
      pageText.includes("display media that may contain sensitive content");
    const isSearchSettings =
      path.includes("/settings/search") ||
      pageText.includes("hide sensitive content");
    if (!isContentSettings && !isSearchSettings) {
      return null;
    }

    return {
      site: "x",
      checkedAt: new Date().toISOString(),
      url: location.href,
      displaySensitiveMedia: controlNearText([
        /display media that may contain sensitive content/,
        /media that may contain sensitive content/
      ]),
      hideSensitiveSearch: controlNearText([
        /hide sensitive content/,
        /sensitive content.*search/
      ])
    };
  }

  function redditSnapshot() {
    const host = location.hostname.toLowerCase();
    const path = location.pathname.toLowerCase();
    const pageText = visibleText();
    const isSettings =
      host.endsWith("reddit.com") &&
      (
        path.includes("/settings/preferences") ||
        path.includes("/prefs") ||
        pageText.includes("show mature") ||
        pageText.includes("blur mature")
      );
    if (!isSettings) {
      return null;
    }

    return {
      site: "reddit",
      checkedAt: new Date().toISOString(),
      url: location.href,
      showMatureContent: controlNearText([
        /show mature/,
        /show nsfw/,
        /adult content/,
        /over eighteen/
      ]),
      blurMatureMedia: controlNearText([
        /blur mature/,
        /blur nsfw/,
        /blur.*media/,
        /blur.*image/
      ])
    };
  }

  function currentSnapshot() {
    if (/^(?:x|twitter|mobile\.x)\.com$/i.test(location.hostname)) {
      return xSnapshot();
    }
    return redditSnapshot();
  }

  function report() {
    const snapshot = currentSnapshot();
    if (!snapshot) {
      return;
    }
    const serialized = JSON.stringify(snapshot);
    if (lastPayload === serialized) {
      return;
    }
    lastPayload = serialized;
    document.documentElement.dataset[CHECKED_MARKER] = "checked";
    runtime.sendMessage({
      type: "quietgate.platformControls",
      payload: snapshot
    });
  }

  let queued = false;
  function scheduleReport() {
    if (queued) {
      return;
    }
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      report();
    });
  }

  scheduleReport();
  window.addEventListener("load", scheduleReport, { once: true });
  const observer = new MutationObserver(scheduleReport);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["checked", "aria-checked", "data-checked"]
  });
})();
