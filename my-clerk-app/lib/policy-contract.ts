import { z } from "zod";

export const BROWSER_TUNING_FEATURES = [
  "youtubeHome",
  "youtubeVideoSidebar",
  "youtubeRecommendations",
  "youtubeLiveChat",
  "youtubePlaylists",
  "youtubeFundraisers",
  "youtubeEndScreens",
  "youtubeEndScreenCards",
  "youtubeShorts",
  "youtubeComments",
  "youtubeMixes",
  "youtubeMerch",
  "youtubeVideoInfo",
  "youtubeTopHeader",
  "youtubeNotifications",
  "youtubeSearch",
  "youtubeExplore",
  "youtubeMoreFromYouTube",
  "youtubeSubscriptions",
  "youtubeAutoplay",
  "youtubeAnnotations",
  "youtubeUsageTracking",
  "youtubeDailyLimit",
  "xSensitiveMedia",
  "xExplicitContent",
  "xExplicitSearch",
  "xVideos",
  "xPhotos",
  "xMediaCards",
  "xExploreTrends",
  "instagramReels",
  "instagramExplore",
  "instagramSuggested",
  "instagramStories",
  "redditPopularAll",
  "redditRecommendations",
  "redditNSFW",
  "redditMedia",
  "redditSidebars",
] as const;

export type BrowserTuningFeature = (typeof BROWSER_TUNING_FEATURES)[number];
export type FeatureRecord = Record<BrowserTuningFeature, boolean>;
export type QuietGateMode = "open" | "focus" | "strict";

const FEATURE_SET = new Set<string>(BROWSER_TUNING_FEATURES);

const FOCUS_FEATURES = new Set<BrowserTuningFeature>([
  "youtubeHome",
  "youtubeShorts",
  "youtubeUsageTracking",
  "xSensitiveMedia",
  "xVideos",
  "instagramReels",
  "instagramExplore",
  "instagramSuggested",
  "redditPopularAll",
  "redditRecommendations",
]);

const falseFeatureRecord = () =>
  Object.fromEntries(BROWSER_TUNING_FEATURES.map((feature) => [feature, false])) as FeatureRecord;

export function defaultFeaturesForMode(mode: QuietGateMode): FeatureRecord {
  if (mode === "strict") {
    return Object.fromEntries(BROWSER_TUNING_FEATURES.map((feature) => [feature, true])) as FeatureRecord;
  }

  if (mode === "focus") {
    return Object.fromEntries(
      BROWSER_TUNING_FEATURES.map((feature) => [feature, FOCUS_FEATURES.has(feature)]),
    ) as FeatureRecord;
  }

  return falseFeatureRecord();
}

function uniqueSorted(values: string[]) {
  return Array.from(new Set(values)).sort();
}

export function normalizeDomain(rawDomain: string) {
  const withoutProtocol = rawDomain
    .trim()
    .toLowerCase()
    .replace(/^[a-z][a-z0-9+.-]*:\/\//, "")
    .replace(/^\*\./, "");

  return withoutProtocol
    .split(/[/?#]/)[0]
    .replace(/:\d+$/, "")
    .replace(/^\.+|\.+$/g, "");
}

const domainSchema = z
  .string()
  .transform(normalizeDomain)
  .pipe(
    z
      .string()
      .min(1)
      .max(253)
      .regex(/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{1,62}$/),
  );

const dateStringSchema = z
  .string()
  .refine((value) => !Number.isNaN(Date.parse(value)), "Expected an ISO date string")
  .transform((value) => new Date(value).toISOString());

const featureRecordSchema = z
  .record(z.string(), z.boolean())
  .superRefine((features, context) => {
    for (const key of Object.keys(features)) {
      if (!FEATURE_SET.has(key)) {
        context.addIssue({
          code: "custom",
          message: `Unknown browser tuning feature: ${key}`,
          path: [key],
        });
      }
    }

    for (const key of BROWSER_TUNING_FEATURES) {
      if (!(key in features)) {
        context.addIssue({
          code: "custom",
          message: `Missing browser tuning feature: ${key}`,
          path: [key],
        });
      }
    }
  })
  .transform((features) => {
    return Object.fromEntries(
      BROWSER_TUNING_FEATURES.map((feature) => [feature, Boolean(features[feature])]),
    ) as FeatureRecord;
  });

const appRuleSchema = z
  .object({
    bundleIdentifier: z.string().trim().min(1).max(255),
    displayName: z.string().trim().min(1).max(255),
    isEnabled: z.boolean(),
    addedAt: dateStringSchema,
  })
  .strict();

function normalizeAppRules(rules: z.infer<typeof appRuleSchema>[]) {
  const byBundleIdentifier = new Map<string, z.infer<typeof appRuleSchema>>();
  for (const rule of rules) {
    byBundleIdentifier.set(rule.bundleIdentifier, rule);
  }

  return Array.from(byBundleIdentifier.values()).sort((lhs, rhs) =>
    lhs.bundleIdentifier.localeCompare(rhs.bundleIdentifier),
  );
}

export const quietGatePolicySchema = z
  .object({
    schemaVersion: z.literal(1),
    mode: z.enum(["open", "focus", "strict"]),
    adultBlockingEnabled: z.boolean(),
    browser: z
      .object({
        features: featureRecordSchema,
        blockedDomains: z.array(domainSchema).max(500).transform(uniqueSorted),
        blockedCategories: z.array(z.literal("adultContent")).max(25).transform(uniqueSorted),
        options: z
          .object({
            explicitHideStyle: z.enum(["post", "media", "placeholder"]),
            youtubeDailyLimitMinutes: z.number().int().min(5).max(480),
          })
          .strict(),
      })
      .strict(),
    schedules: z
      .object({
        enabled: z.boolean(),
        dailyFocusWindows: z
          .array(
            z
              .object({
                id: z.string().uuid(),
                title: z.string().trim().min(1).max(120),
                startMinute: z.number().int().min(0).max(1439),
                endMinute: z.number().int().min(0).max(1439),
                mode: z.enum(["focus", "strict"]),
                isEnabled: z.boolean(),
              })
              .strict(),
          )
          .max(32),
      })
      .strict(),
    applications: z
      .object({
        enforcementEnabled: z.boolean(),
        blocked: z.array(appRuleSchema).max(500).transform(normalizeAppRules),
        allowed: z.array(appRuleSchema).max(500).transform(normalizeAppRules),
      })
      .strict(),
  })
  .strict();

export type QuietGatePolicy = z.infer<typeof quietGatePolicySchema>;

export const policyUpdateRequestSchema = z
  .object({
    expectedSettingsVersion: z.number().int().min(1),
    policy: quietGatePolicySchema,
  })
  .strict();

export type PolicyUpdateRequest = z.infer<typeof policyUpdateRequestSchema>;

export type PolicyEnvelope = {
  policy: QuietGatePolicy;
  settingsVersion: number;
  updatedAt: string;
};

export function defaultQuietGatePolicy(mode: QuietGateMode = "focus"): QuietGatePolicy {
  return {
    schemaVersion: 1,
    mode,
    adultBlockingEnabled: mode !== "open",
    browser: {
      features: defaultFeaturesForMode(mode),
      blockedDomains: [],
      blockedCategories: mode === "open" ? [] : ["adultContent"],
      options: {
        explicitHideStyle: "post",
        youtubeDailyLimitMinutes: 30,
      },
    },
    schedules: {
      enabled: false,
      dailyFocusWindows: [],
    },
    applications: {
      enforcementEnabled: true,
      blocked: [],
      allowed: [],
    },
  };
}

export function parsePolicy(value: unknown) {
  return quietGatePolicySchema.parse(value);
}

export function parsePolicyUpdateRequest(value: unknown) {
  return policyUpdateRequestSchema.parse(value);
}
