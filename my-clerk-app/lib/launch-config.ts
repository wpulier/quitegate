export type DownloadKind = "mac" | "ios" | "chrome";

type DownloadConfig = {
  label: string;
  envName: string;
  missingTitle: string;
  missingDetail: string;
};

const downloadConfigs: Record<DownloadKind, DownloadConfig> = {
  mac: {
    label: "Download Mac app",
    envName: "NEXT_PUBLIC_MAC_DOWNLOAD_URL",
    missingTitle: "Mac download is not ready yet",
    missingDetail:
      "Tortoise needs a signed and notarized Mac release URL before this button can be public.",
  },
  ios: {
    label: "Install iPhone app",
    envName: "NEXT_PUBLIC_IOS_TESTFLIGHT_URL",
    missingTitle: "iPhone invite is not ready yet",
    missingDetail:
      "Tortoise needs the public TestFlight invite URL before this button can be public.",
  },
  chrome: {
    label: "Connect browser",
    envName: "NEXT_PUBLIC_CHROME_EXTENSION_URL",
    missingTitle: "Browser extension link is not ready yet",
    missingDetail:
      "Tortoise needs the browser extension listing URL before this button can be public.",
  },
};

function cleanURL(value: string | undefined) {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  if (
    trimmed === "https://testflight.apple.com/" ||
    trimmed.includes("YOUR_PUBLIC_INVITE") ||
    trimmed.includes("<owner>") ||
    trimmed.includes("<repo>")
  ) {
    return null;
  }

  return trimmed;
}

export function downloadURL(kind: DownloadKind) {
  return cleanURL(process.env[downloadConfigs[kind].envName]);
}

export function downloadConfig(kind: DownloadKind) {
  return downloadConfigs[kind];
}

export function publicDownloadPath(kind: DownloadKind) {
  return `/download/${kind}`;
}

export function requiredDownloadEnvNames() {
  return [
    downloadConfigs.mac.envName,
    downloadConfigs.ios.envName,
    downloadConfigs.chrome.envName,
  ];
}
