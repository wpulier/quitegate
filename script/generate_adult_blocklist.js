#!/usr/bin/env node

const fs = require("fs");
const https = require("https");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..");
const SOURCES = [
  {
    name: "HaGeZi NSFW",
    url: "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/nsfw-onlydomains.txt"
  },
  {
    name: "StevenBlack porn hosts",
    url: "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
  },
  {
    name: "OISD NSFW",
    url: "https://nsfw.oisd.nl/domainswild",
    optional: true
  }
];

const SEED_DOMAINS = [
  "4tube.com",
  "beeg.com",
  "bongacams.com",
  "brazzers.com",
  "cam4.com",
  "chaturbate.com",
  "drtuber.com",
  "eporner.com",
  "erome.com",
  "fapello.com",
  "faphouse.com",
  "fansly.com",
  "hclips.com",
  "hentaihaven.xxx",
  "livejasmin.com",
  "manyvids.com",
  "motherless.com",
  "nuvid.com",
  "onlyfans.com",
  "perfectgirls.net",
  "pornhub.com",
  "pornpics.com",
  "pornzog.com",
  "redgifs.com",
  "redtube.com",
  "spankbang.com",
  "stripchat.com",
  "tnaflix.com",
  "tube8.com",
  "txxx.com",
  "upornia.com",
  "vjav.com",
  "xhamster.com",
  "xhamster.desi",
  "xhamsterlive.com",
  "xnxx.com",
  "xvideos.com",
  "xvideos2.com",
  "xxxbunker.com",
  "xxxstreams.org",
  "youporn.com"
];

const ADULT_TOKENS = [
  "adult",
  "anal",
  "bdsm",
  "blowjob",
  "boob",
  "brazzers",
  "camgirl",
  "cams",
  "chaturbate",
  "cock",
  "deepthroat",
  "erome",
  "erotic",
  "fansly",
  "fap",
  "fetish",
  "fuck",
  "gonewild",
  "hentai",
  "horny",
  "jav",
  "milf",
  "naked",
  "nude",
  "onlyfans",
  "porn",
  "pornhub",
  "pussy",
  "redgifs",
  "redtube",
  "sex",
  "sexy",
  "spank",
  "strip",
  "teen",
  "throat",
  "tube8",
  "xhamster",
  "xnxx",
  "xvideo",
  "xxx",
  "youporn"
];

const STATIC_RULESETS = [
  { id: "adult-static-1", file: "adult-static-1.json", start: 0, count: 15000, ruleIDBase: 1 },
  { id: "adult-static-2", file: "adult-static-2.json", start: 15000, count: 15000, ruleIDBase: 40001 },
  { id: "adult-static-3", file: "adult-static-3.json", start: 30000, count: 15000, ruleIDBase: 80001 },
  { id: "adult-static-4", file: "adult-static-4.json", start: 45000, count: 15000, ruleIDBase: 120001 }
];

const SUBRESOURCE_TYPES = [
  "sub_frame",
  "stylesheet",
  "script",
  "image",
  "font",
  "object",
  "xmlhttprequest",
  "ping",
  "media",
  "websocket",
  "other"
];

function fetchText(source) {
  return new Promise((resolve, reject) => {
    https.get(source.url, { headers: { "user-agent": "QuietGate blocklist generator" } }, (response) => {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        reject(new Error(`${source.name} returned HTTP ${response.statusCode}`));
        response.resume();
        return;
      }

      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => { body += chunk; });
      response.on("end", () => resolve(body));
    }).on("error", reject);
  });
}

function normalizeDomain(value) {
  let domain = String(value || "")
    .trim()
    .toLowerCase();
  if (!domain || domain.startsWith("#") || domain.startsWith("!")) {
    return null;
  }

  if (/^(?:0\.0\.0\.0|127\.0\.0\.1|::1)\s+/.test(domain)) {
    domain = domain.split(/\s+/)[1] || "";
  } else if (/^\S+\s+\S+/.test(domain)) {
    const parts = domain.split(/\s+/);
    if (/^(?:0\.0\.0\.0|127\.0\.0\.1|::1|255\.255\.255\.255)$/.test(parts[0])) {
      domain = parts[1] || "";
    }
  }

  domain = domain
    .replace(/^\|\|/, "")
    .replace(/^\*\./, "")
    .replace(/\^.*$/, "")
    .replace(/\$.*$/, "")
    .replace(/\s+#.*$/, "")
    .replace(/\.$/, "");

  if (
    !domain ||
    domain === "localhost" ||
    domain === "local" ||
    /^[0-9a-f:.]+$/i.test(domain) ||
    !domain.includes(".") ||
    domain.length > 253 ||
    !/^[a-z0-9][a-z0-9.-]*[a-z0-9]$/.test(domain) ||
    domain.split(".").some((part) => !part || part.length > 63)
  ) {
    return null;
  }

  return domain;
}

function parseDomains(text) {
  const domains = [];
  for (const line of text.split(/\r?\n/)) {
    const domain = normalizeDomain(line);
    if (domain) {
      domains.push(domain);
    }
  }
  return domains;
}

function priorityScore(domain) {
  let score = 0;
  if (SEED_DOMAINS.includes(domain)) {
    score += 1000;
  }
  const compact = domain.replace(/[^a-z0-9]/g, "");
  for (const token of ADULT_TOKENS) {
    if (compact.includes(token)) {
      score += 30;
    }
  }
  if (domain.split(".").length <= 2) {
    score += 20;
  }
  score -= Math.min(domain.length / 20, 10);
  return score;
}

function rankedDomains(domains) {
  const unique = [...new Set([...SEED_DOMAINS, ...domains].map(normalizeDomain).filter(Boolean))];
  return unique.sort((left, right) => {
    const score = priorityScore(right) - priorityScore(left);
    if (score !== 0) {
      return score;
    }
    const length = left.length - right.length;
    if (length !== 0) {
      return length;
    }
    return left.localeCompare(right);
  });
}

function chromeRulesForDomains(domains, ruleIDBase) {
  const rules = [];
  domains.forEach((domain, index) => {
    const id = ruleIDBase + (index * 2);
    rules.push({
      id,
      priority: 3,
      action: {
        type: "redirect",
        redirect: { extensionPath: "/blocked/blocked.html" }
      },
      condition: {
        urlFilter: `||${domain}^`,
        resourceTypes: ["main_frame"]
      }
    });
    rules.push({
      id: id + 1,
      priority: 2,
      action: { type: "block" },
      condition: {
        urlFilter: `||${domain}^`,
        resourceTypes: SUBRESOURCE_TYPES
      }
    });
  });
  return rules;
}

function writeJSON(relativePath, value) {
  const outputPath = path.join(ROOT_DIR, relativePath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(value)}\n`);
}

function swiftString(value) {
  return JSON.stringify(value);
}

function writeSwiftPreset(domains, metadata) {
  const seed = domains.slice(0, 500);
  const sourceLines = metadata.map((item) => `  // - ${item.name}: ${item.count} domains`).join("\n");
  const body = `import Foundation

enum AdultContentPreset {
  static let sourceSummary = """
Generated by script/generate_adult_blocklist.js from pinned public DNS blocklist snapshots.
${metadata.map((item) => `${item.name}: ${item.count} domains`).join("\n")}
"""

${sourceLines}
  static let domains = [
${seed.map((domain) => `    ${swiftString(domain)}`).join(",\n")}
  ]
}
`;
  fs.writeFileSync(
    path.join(ROOT_DIR, "QuietGate", "Models", "AdultContentPreset.swift"),
    body
  );
}

async function main() {
  const allDomains = [];
  const metadata = [];
  for (const source of SOURCES) {
    try {
      const text = await fetchText(source);
      const domains = parseDomains(text);
      for (const domain of domains) {
        allDomains.push(domain);
      }
      metadata.push({ name: source.name, count: domains.length, url: source.url });
      console.log(`${source.name}: ${domains.length} domains`);
    } catch (error) {
      if (!source.optional) {
        throw error;
      }
      console.warn(`${source.name}: skipped (${error.message})`);
    }
  }

  const domains = rankedDomains(allDomains);
  const generatedAt = new Date().toISOString();
  const domainPayload = {
    schemaVersion: 1,
    generatedAt,
    sources: metadata,
    totalDomains: domains.length,
    domains
  };
  writeJSON("ChromeExtension/rules/adult-domains.json", domainPayload);
  writeJSON("FirefoxExtension/rules/adult-domains.json", domainPayload);

  for (const ruleset of STATIC_RULESETS) {
    const slice = domains.slice(ruleset.start, ruleset.start + ruleset.count);
    writeJSON(
      `ChromeExtension/rules/${ruleset.file}`,
      chromeRulesForDomains(slice, ruleset.ruleIDBase)
    );
  }

  writeSwiftPreset(domains, metadata);
  console.log(`Generated ${domains.length} ranked adult domains at ${generatedAt}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
