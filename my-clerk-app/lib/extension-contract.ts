import { z } from "zod";
import { boundedJsonRecordSchema } from "@/lib/json-contract";

const extensionIdSchema = z
  .string()
  .trim()
  .min(16)
  .max(128)
  .regex(/^[a-z]{16,128}$/);

const tokenStringSchema = z
  .string()
  .trim()
  .min(16)
  .max(256)
  .regex(/^[A-Za-z0-9._:-]+$/);

const nullableTrimmedString = (maxLength: number) =>
  z
    .string()
    .trim()
    .max(maxLength)
    .optional()
    .nullable()
    .transform((value) => (value ? value : null));

export const extensionLinkRequestSchema = z
  .object({
    extensionId: extensionIdSchema,
    installationId: tokenStringSchema,
    nonce: tokenStringSchema,
    extensionVersion: nullableTrimmedString(80),
  })
  .strict();

export const extensionExchangeRequestSchema = extensionLinkRequestSchema
  .extend({
    code: tokenStringSchema,
  })
  .strict();

export const extensionHealthRequestSchema = z
  .object({
    extensionVersion: nullableTrimmedString(80),
    rulesetVersion: nullableTrimmedString(80),
    scriptVersions: boundedJsonRecordSchema.default({}),
    canaryStatus: boundedJsonRecordSchema.default({}),
    adultProtection: boundedJsonRecordSchema.default({}),
    platformMetadata: boundedJsonRecordSchema.default({}),
    enabledPermissions: boundedJsonRecordSchema.default({}),
    recentBlockCounters: boundedJsonRecordSchema.default({}),
    lastSyncAt: nullableTrimmedString(80),
  })
  .strict();

export type ExtensionLinkRequest = z.infer<typeof extensionLinkRequestSchema>;
export type ExtensionExchangeRequest = z.infer<typeof extensionExchangeRequestSchema>;
export type ExtensionHealthRequest = z.infer<typeof extensionHealthRequestSchema>;

export function parseExtensionLinkRequest(value: unknown) {
  return extensionLinkRequestSchema.parse(value);
}

export function parseExtensionExchangeRequest(value: unknown) {
  return extensionExchangeRequestSchema.parse(value);
}

export function parseExtensionHealthRequest(value: unknown) {
  return extensionHealthRequestSchema.parse(value);
}
