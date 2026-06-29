import { z } from "zod";

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

const jsonRecordSchema = z.record(z.string(), z.unknown());

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
    scriptVersions: jsonRecordSchema.default({}),
    canaryStatus: jsonRecordSchema.default({}),
    adultProtection: jsonRecordSchema.default({}),
    platformMetadata: jsonRecordSchema.default({}),
    enabledPermissions: jsonRecordSchema.default({}),
    recentBlockCounters: jsonRecordSchema.default({}),
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
