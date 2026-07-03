import { NextResponse, type NextRequest } from "next/server";
import { downloadConfig, downloadURL } from "@/lib/launch-config";

export async function GET(request: NextRequest) {
  const url = downloadURL("mac");
  if (url && (await macDownloadLooksPublic(url))) {
    return NextResponse.redirect(url);
  }

  const config = downloadConfig("mac");
  return new Response(missingDownloadHTML(config.missingTitle, config.missingDetail), {
    status: 503,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "x-tortoise-download-status": "missing-mac-url",
      "x-tortoise-origin": request.nextUrl.origin,
    },
  });
}

async function macDownloadLooksPublic(url: string) {
  const releaseRef = githubLatestReleaseRef(url);
  if (!releaseRef) {
    return true;
  }

  try {
    const response = await fetch(
      `https://api.github.com/repos/${releaseRef.owner}/${releaseRef.repo}/releases/latest`,
      {
        cache: "no-store",
        headers: {
          accept: "application/vnd.github+json",
          "user-agent": "tortoise-download-check",
        },
      },
    );

    if (!response.ok) {
      return false;
    }

    const release = (await response.json()) as {
      name?: string;
      tag_name?: string;
    };
    const marker = `${release.tag_name ?? ""} ${release.name ?? ""}`.toLowerCase();
    return !marker.includes("local");
  } catch {
    return false;
  }
}

function githubLatestReleaseRef(url: string) {
  try {
    const parsed = new URL(url);
    if (parsed.hostname !== "github.com") {
      return null;
    }

    const parts = parsed.pathname.split("/").filter(Boolean);
    if (
      parts.length >= 5 &&
      parts[2] === "releases" &&
      parts[3] === "latest" &&
      parts[4] === "download"
    ) {
      return { owner: parts[0], repo: parts[1] };
    }
  } catch {
    return null;
  }

  return null;
}

function missingDownloadHTML(title: string, detail: string) {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${title}</title><style>body{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;margin:0;background:#fafafa;color:#09090b}.wrap{max-width:680px;margin:0 auto;padding:72px 24px}.card{background:white;border:1px solid #e4e4e7;border-radius:10px;padding:28px;box-shadow:0 1px 2px rgba(0,0,0,.04)}h1{font-size:32px;line-height:1.1;margin:0 0 12px}p{line-height:1.6;color:#52525b}a{color:#09090b;font-weight:700}</style></head><body><main class="wrap"><section class="card"><h1>${title}</h1><p>${detail}</p><p><a href="/">Back to Tortoise</a></p></section></main></body></html>`;
}
