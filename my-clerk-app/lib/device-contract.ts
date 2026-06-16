import { z } from "zod";

export const devicePlatformSchema = z.enum([
  "macos",
  "ios",
  "web",
  "chrome",
  "firefox",
  "safari",
]);

const jsonRecordSchema = z.record(z.string(), z.unknown());

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
    name: z.string().trim().min(1).max(120).default("QuietGate device"),
    publicKey: nullableTrimmedString(5000),
    appVersion: nullableTrimmedString(80),
    helperVersion: nullableTrimmedString(80),
    platformMetadata: jsonRecordSchema.default({}),
  })
  .strict();

export const deviceHealthRequestSchema = z
  .object({
    appVersion: nullableTrimmedString(80),
    helperVersion: nullableTrimmedString(80),
    rulesetVersion: nullableTrimmedString(80),
    scriptVersions: jsonRecordSchema.default({}),
    canaryStatus: jsonRecordSchema.default({}),
    adultProtection: jsonRecordSchema.default({}),
    platformMetadata: jsonRecordSchema.default({}),
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
