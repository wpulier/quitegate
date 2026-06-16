(() => {
  const runtime = globalThis.chrome?.runtime || globalThis.browser?.runtime;
  if (!runtime) {
    return;
  }

  const controllerKey = "__quietgateWebAdultClassifier";
  const blockedClass = "qg-web-adult-blocked";
  const styleID = "quietgate-web-adult-style";
  const supportedHostPattern =
    /(?:^|\.)((x|twitter|youtube|instagram|reddit)\.com|mobile\.x\.com|old\.reddit\.com|new\.reddit\.com)$/i;

  if (window[controllerKey]?.version === "2026.06.11.01") {
    return;
  }
  window[controllerKey]?.dispose?.();

  function normalizeHostname(value) {
    return String(value || "")
      .trim()
      .toLowerCase()
      .replace(/^\*\./, "")
      .replace(/\.$/, "");
  }

  function adultDecision(surface, action, reason, confidence, source) {
    return { surface, action, reason, confidence, source };
  }

  function shouldSkipPage() {
    if (!/^https?:$/.test(location.protocol)) {
      return true;
    }
    const hostname = normalizeHostname(location.hostname);
    return supportedHostPattern.test(hostname);
  }

  function ensureStyle() {
    if (document.getElementById(styleID)) {
      return;
    }
    const style = document.createElement("style");
    style.id = styleID;
    style.textContent = `
      html.${blockedClass},
      html.${blockedClass} body {
        min-height: 100% !important;
        overflow: hidden !important;
      }

      .qg-web-adult-shell {
        position: fixed !important;
        inset: 0 !important;
        z-index: 2147483647 !important;
        display: grid !important;
        place-items: center !important;
        padding: 28px !important;
        background: #f7f8fa !important;
        color: #24262a !important;
        font: 16px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif !important;
      }

      .qg-web-adult-panel {
        width: min(560px, 100%) !important;
        padding: 34px !important;
        border: 1px solid #dfe3e7 !important;
        border-radius: 8px !important;
        background: #fff !important;
        box-shadow: 0 20px 70px rgba(30, 38, 46, 0.10) !important;
      }

      .qg-web-adult-mark {
        width: 52px !important;
        height: 52px !important;
        display: grid !important;
        place-items: center !important;
        border-radius: 50% !important;
        margin-bottom: 22px !important;
        background: #e9f7ef !important;
        color: #20bf55 !important;
        font-size: 30px !important;
        font-weight: 800 !important;
      }

      .qg-web-adult-eyebrow {
        margin: 0 0 8px !important;
        color: #6d7278 !important;
        font-weight: 800 !important;
      }

      .qg-web-adult-panel h1 {
        margin: 0 !important;
        font-size: clamp(32px, 7vw, 50px) !important;
        line-height: 1.03 !important;
        letter-spacing: 0 !important;
        color: #24262a !important;
      }

      .qg-web-adult-message {
        margin: 18px 0 0 !important;
        max-width: 450px !important;
        color: #62686f !important;
        font-size: 19px !important;
      }

      .qg-web-adult-reason {
        margin: 14px 0 0 !important;
        color: #777d84 !important;
        font-size: 13px !important;
        word-break: break-word !important;
      }

      .qg-web-adult-actions {
        display: flex !important;
        flex-wrap: wrap !important;
        gap: 10px !important;
        margin-top: 28px !important;
      }

      .qg-web-adult-actions button {
        appearance: none !important;
        min-height: 42px !important;
        padding: 0 18px !important;
        border-radius: 8px !important;
        border: 1px solid #cfd6dd !important;
        background: #fff !important;
        color: #24262a !important;
        font: inherit !important;
        font-weight: 750 !important;
        cursor: pointer !important;
      }

      .qg-web-adult-actions button.qg-primary {
        border-color: #0077ee !important;
        background: #0077ee !important;
        color: #fff !important;
      }

      .qg-web-adult-actions button:focus-visible {
        outline: 4px solid #9fc9ff !important;
        outline-offset: 2px !important;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  function compactText(value, limit) {
    return String(value || "")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, limit);
  }

  function metaText() {
    const parts = [];
    for (const selector of [
      'meta[name="description"]',
      'meta[name="keywords"]',
      'meta[property="og:title"]',
      'meta[property="og:description"]',
      'meta[name="twitter:title"]',
      'meta[name="twitter:description"]'
    ]) {
      const value = document.querySelector(selector)?.getAttribute("content");
      if (value) {
        parts.push(value);
      }
    }
    return compactText(parts.join(" "), 1600);
  }

  function linkHostnames() {
    const hosts = [];
    for (const anchor of Array.from(document.links || []).slice(0, 160)) {
      try {
        const host = normalizeHostname(new URL(anchor.href, location.href).hostname);
        if (host && host !== location.hostname) {
          hosts.push(host);
        }
      } catch (_error) {
        // Ignore malformed links.
      }
    }
    return [...new Set(hosts)].slice(0, 80);
  }

  function collectPayload() {
    const headings = Array.from(document.querySelectorAll("h1,h2,h3,[role='heading']"))
      .slice(0, 30)
      .map((node) => node.textContent || "")
      .join(" ");
    return {
      url: location.href,
      hostname: normalizeHostname(location.hostname),
      pathname: location.pathname,
      title: compactText(document.title || "", 300),
      meta: metaText(),
      headings: compactText(headings, 1800),
      bodyText: compactText(document.body?.innerText || "", 6000),
      linkHostnames: linkHostnames()
    };
  }

  function sendMessage(message) {
    return new Promise((resolve) => {
      try {
        const result = runtime.sendMessage(message, resolve);
        if (result && typeof result.then === "function") {
          result.then(resolve).catch((error) => resolve({ ok: false, error: error?.message || String(error) }));
        }
      } catch (error) {
        resolve({ ok: false, error: error?.message || String(error) });
      }
    });
  }

  function renderBlocked(result) {
    if (document.documentElement.classList.contains(blockedClass)) {
      return;
    }
    ensureStyle();
    document.documentElement.classList.add(blockedClass);
    document.documentElement.dataset.quietgateWebAdultBlocked = "true";
    document.documentElement.dataset.quietgateWebAdultReason = result.reason || "";
    document.documentElement.dataset.quietgateWebAdultScore = String(result.score || 0);
    document.documentElement.dataset.quietgateWebAdultDecision = JSON.stringify(adultDecision(
      "web-page",
      "block",
      result.reason || "page-signals",
      result.score || 0,
      result.matchedDomain || location.hostname
    ));

    const shell = document.createElement("main");
    shell.className = "qg-web-adult-shell";
    shell.innerHTML = `
      <section class="qg-web-adult-panel" aria-labelledby="qg-web-adult-title">
        <div class="qg-web-adult-mark" aria-hidden="true">Q</div>
        <p class="qg-web-adult-eyebrow">QuietGate</p>
        <h1 id="qg-web-adult-title">Adult content blocked</h1>
        <p class="qg-web-adult-message">QuietGate blocked this page using your Adult Content rules.</p>
        <p class="qg-web-adult-reason"></p>
        <div class="qg-web-adult-actions">
          <button class="qg-primary" type="button" data-qg-action="back">Go Back</button>
          <button type="button" data-qg-action="report">Always block this site</button>
        </div>
      </section>
    `;
    shell.querySelector(".qg-web-adult-reason").textContent =
      result.matchedDomain
        ? `Matched: ${result.matchedDomain}`
        : `Reason: ${result.reason || "page signals"}`;
    shell.querySelector('[data-qg-action="back"]').addEventListener("click", () => {
      if (history.length > 1) {
        history.back();
      } else {
        location.href = "about:blank";
      }
    });
    shell.querySelector('[data-qg-action="report"]').addEventListener("click", async (event) => {
      const button = event.currentTarget;
      button.disabled = true;
      button.textContent = "Saving...";
      const response = await sendMessage({
        type: "quietgate.reportMissedAdultSite",
        payload: {
          url: location.href,
          domain: location.hostname,
          title: document.title,
          reason: result.reason || ""
        }
      });
      button.textContent = response?.ok ? "Saved" : "Open QuietGate to add";
    });

    if (document.body) {
      document.body.replaceChildren(shell);
    } else {
      document.documentElement.appendChild(shell);
    }
  }

  let disposed = false;
  let timer = null;
  let lastToken = "";

  async function classify() {
    if (disposed || shouldSkipPage()) {
      return;
    }
    const payload = collectPayload();
    const token = `${payload.url}|${payload.title}|${payload.meta}|${payload.headings}|${payload.bodyText.slice(0, 800)}`;
    if (token === lastToken) {
      return;
    }
    lastToken = token;
    const result = await sendMessage({
      type: "quietgate.classifyWebAdultPage",
      payload
    });
    if (result?.ok && result.block) {
      renderBlocked(result);
    }
  }

  function queueClassify(delay = 0) {
    clearTimeout(timer);
    timer = setTimeout(classify, delay);
  }

  if (!shouldSkipPage()) {
    queueClassify(0);
    window.addEventListener("DOMContentLoaded", () => queueClassify(0), { once: true });
    window.addEventListener("load", () => queueClassify(100), { once: true });
    setTimeout(() => queueClassify(0), 800);
    setTimeout(() => queueClassify(0), 1800);
  }

  window[controllerKey] = {
    version: "2026.06.11.01",
    dispose() {
      disposed = true;
      clearTimeout(timer);
      document.documentElement.classList.remove(blockedClass);
    }
  };
})();
