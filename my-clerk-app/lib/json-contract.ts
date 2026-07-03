import { z, type RefinementCtx } from "zod";

const MAX_DEPTH = 4;
const MAX_KEYS = 64;
const MAX_ARRAY_LENGTH = 64;
const MAX_STRING_LENGTH = 1000;
const MAX_SERIALIZED_BYTES = 8000;

export const boundedJsonRecordSchema = z
  .record(z.string().min(1).max(80), z.unknown())
  .superRefine((value, context) => {
    validateJSONValue(value, context, []);

    const encoded = new TextEncoder().encode(JSON.stringify(value));
    if (encoded.byteLength > MAX_SERIALIZED_BYTES) {
      context.addIssue({
        code: "custom",
        message: `Metadata must be ${MAX_SERIALIZED_BYTES} bytes or less.`,
      });
    }
  });

function validateJSONValue(value: unknown, context: RefinementCtx, path: Array<string | number>) {
  if (path.length > MAX_DEPTH) {
    context.addIssue({
      code: "custom",
      message: `Metadata is nested deeper than ${MAX_DEPTH} levels.`,
      path,
    });
    return;
  }

  if (
    value === null ||
    typeof value === "boolean" ||
    typeof value === "number"
  ) {
    return;
  }

  if (typeof value === "string") {
    if (value.length > MAX_STRING_LENGTH) {
      context.addIssue({
        code: "custom",
        message: `Metadata strings must be ${MAX_STRING_LENGTH} characters or less.`,
        path,
      });
    }
    return;
  }

  if (Array.isArray(value)) {
    if (value.length > MAX_ARRAY_LENGTH) {
      context.addIssue({
        code: "custom",
        message: `Metadata arrays must contain ${MAX_ARRAY_LENGTH} items or fewer.`,
        path,
      });
      return;
    }
    value.forEach((item, index) => validateJSONValue(item, context, [...path, index]));
    return;
  }

  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length > MAX_KEYS) {
      context.addIssue({
        code: "custom",
        message: `Metadata objects must contain ${MAX_KEYS} keys or fewer.`,
        path,
      });
      return;
    }

    for (const [key, child] of entries) {
      if (key.length > 80) {
        context.addIssue({
          code: "custom",
          message: "Metadata keys must be 80 characters or less.",
          path: [...path, key],
        });
      }
      validateJSONValue(child, context, [...path, key]);
    }
    return;
  }

  context.addIssue({
    code: "custom",
    message: "Metadata must be JSON serializable.",
    path,
  });
}
