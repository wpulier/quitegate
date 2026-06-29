import { z } from "zod";

export const supportedUsageSiteIDs = ["youtube", "x", "instagram", "reddit"] as const;

export const usageSiteIDSchema = z
  .enum(supportedUsageSiteIDs)
  .or(z.literal("twitter"))
  .transform((value) => (value === "twitter" ? "x" : value));

const nullableTrimmedString = (maxLength: number) =>
  z
    .string()
    .trim()
    .max(maxLength)
    .optional()
    .nullable()
    .transform((value) => (value ? value : null));

const optionalNonNegativeInt = z
  .number()
  .int()
  .min(0)
  .optional()
  .nullable()
  .transform((value) => (value == null ? null : value));

const jsonRecordSchema = z.record(z.string(), z.unknown());

export const siteUsageValueSchema = z
  .object({
    siteID: usageSiteIDSchema,
    title: nullableTrimmedString(80),
    date: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/),
    totalSeconds: z.number().int().min(0),
    lifetimeSeconds: z.number().int().min(0).default(0),
    activityCount: optionalNonNegativeInt,
    lifetimeActivityCount: optionalNonNegativeInt,
    activityLabel: nullableTrimmedString(40),
    videoCount: optionalNonNegativeInt,
    lifetimeVideoCount: optionalNonNegativeInt,
    limitSeconds: optionalNonNegativeInt,
    limitReached: z.boolean().optional().nullable().default(false),
    lastUpdatedAt: nullableTrimmedString(80),
  })
  .strict();

export const siteUsageSourceSchema = z
  .object({
    sourceID: nullableTrimmedString(180),
    sourceType: z
      .enum(["browser", "web", "ios", "macos", "chrome_extension", "firefox", "safari"])
      .optional()
      .nullable(),
    label: nullableTrimmedString(180),
    browserID: nullableTrimmedString(80),
    browserName: nullableTrimmedString(120),
    profileID: nullableTrimmedString(120),
    profileName: nullableTrimmedString(120),
    deviceName: nullableTrimmedString(120),
    platformMetadata: jsonRecordSchema.default({}),
  })
  .strict()
  .default({
    sourceID: null,
    sourceType: null,
    label: null,
    browserID: null,
    browserName: null,
    profileID: null,
    profileName: null,
    deviceName: null,
    platformMetadata: {},
  });

export const siteUsageReportRequestSchema = z
  .object({
    schemaVersion: z.number().int().min(1).default(1),
    sites: z.array(siteUsageValueSchema).max(16).default([]),
    source: siteUsageSourceSchema,
  })
  .strict();

export type UsageSiteID = z.infer<typeof usageSiteIDSchema>;
export type SiteUsageValue = z.infer<typeof siteUsageValueSchema>;
export type SiteUsageSource = z.infer<typeof siteUsageSourceSchema>;
export type SiteUsageReportRequest = z.infer<typeof siteUsageReportRequestSchema>;

export function parseSiteUsageReportRequest(value: unknown) {
  return siteUsageReportRequestSchema.parse(value);
}
