import fs from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const extensionDir = path.join(rootDir, "dist", "chrome-store");
const port = Number(process.argv[2] || 4175);

const previewRuntime = `
<script>
  const previewSettings = {
    mode: "focus",
    source: "remote",
    blockedRuleCount: 12,
    policySettingsVersion: 18,
    extensionLastSyncAt: new Date().toISOString(),
    features: {
      youtubeHome: true,
      youtubeShorts: true,
      youtubeUsageTracking: true,
      xSensitiveMedia: true,
      xVideos: true,
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      redditPopularAll: true,
      redditRecommendations: true
    },
    options: { explicitHideStyle: "post", youtubeDailyLimitMinutes: 30 }
  };
  const previewStatus = {
    ok: true,
    signedIn: true,
    device: { name: "Chrome · Will" },
    policySettingsVersion: 18,
    lastSyncAt: new Date().toISOString(),
    permissions: { optionalAllSites: true, incognitoAllowed: false }
  };
  window.chrome = {
    runtime: {
      lastError: null,
      sendMessage(message, callback) {
        const response = message.type === "quietgate.extensionStatus" ? previewStatus : { ok: true };
        callback?.(response);
      }
    },
    storage: {
      local: {
        async get(defaults) {
          return {
            ...defaults,
            ...previewSettings,
            features: { ...defaults.features, ...previewSettings.features },
            options: { ...defaults.options, ...previewSettings.options }
          };
        }
      }
    },
    tabs: {
      create() {},
      query(_query, callback) { callback?.([]); }
    }
  };
</script>`;

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml"
};

const server = http.createServer(async (request, response) => {
  try {
    const requestURL = new URL(request.url || "/", `http://127.0.0.1:${port}`);
    const requestPath = requestURL.pathname;
    const relativePath = requestPath === "/" ? "popup/popup.html" : requestPath.replace(/^\/+/, "");
    const filePath = path.resolve(extensionDir, relativePath);
    if (!filePath.startsWith(`${extensionDir}${path.sep}`)) {
      response.writeHead(403).end("Forbidden");
      return;
    }

    let body = await fs.readFile(filePath);
    if (relativePath === "popup/popup.html") {
      const runtime = requestURL.searchParams.get("signedOut") === "1"
        ? previewRuntime.replace("signedIn: true", "signedIn: false")
        : previewRuntime;
      body = Buffer.from(
        body
          .toString("utf8")
          .replace('href="popup.css"', 'href="/popup/popup.css"')
          .replace('<script src="popup.js"></script>', `${runtime}<script src="/popup/popup.js"></script>`)
      );
    }
    response.writeHead(200, {
      "cache-control": "no-store",
      "content-type": mimeTypes[path.extname(filePath)] || "application/octet-stream"
    });
    response.end(body);
  } catch (error) {
    response.writeHead(error?.code === "ENOENT" ? 404 : 500).end(error?.message || "Preview error");
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`QuietGate popup preview listening on http://127.0.0.1:${port}`);
});
