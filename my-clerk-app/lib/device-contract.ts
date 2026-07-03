import { z } from "zod";
import { boundedJsonRecordSchema } from "@/lib/json-contract";

export const devicePlatformSchema = z.enum([
  "macos",
  "ios",
  "web",
  "chrome",
  "chrome_extension",
  "firefox",
  "safari",
]);

const nullableTrimmedString = (maxLength: number) =>
  z
    .string()
    .trim()
    .max(maxLength)
    .optional()
    .nullable()
    .transform((value) => (value ? value : null));

export const deviceRegistrationRequestSchema = z
  .object({
    installationId: z
      .string()
      .trim()
      .min(1)
      .max(128)
      .regex(/^[A-Za-z0-9._:-]+$/),
    platform: devicePlatformSchema.default("web"),
    name: z.string().trim().min(1).max(120).default("Tortoise device"),
    publicKey: nullableTrimmedString(5000),
    appVersion: nullableTrimmedString(80),
    helperVersion: nullableTrimmedString(80),
    platformMetadata: boundedJsonRecordSchema.default({}),
  })
  .strict();

export const deviceHealthRequestSchema = z
  .object({
    appVersion: nullableTrimmedString(80),
    helperVersion: nullableTrimmedString(80),
    rulesetVersion: nullableTrimmedString(80),
    scriptVersions: boundedJsonRecordSchema.default({}),
    canaryStatus: boundedJsonRecordSchema.default({}),
    adultProtection: boundedJsonRecordSchema.default({}),
    platformMetadata: boundedJsonRecordSchema.default({}),
  })
  .strict();

export type DeviceRegistrationRequest = z.infer<
  typeof deviceRegistrationRequestSchema
>;

export type DeviceHealthRequest = z.infer<typeof deviceHealthRequestSchema>;

export function parseDeviceRegistrationRequest(value: unknown) {
  return deviceRegistrationRequestSchema.parse(value);
}

export function parseDeviceHealthRequest(value: unknown) {
  return deviceHealthRequestSchema.parse(value);
}
