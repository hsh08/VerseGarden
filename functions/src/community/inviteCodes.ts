import { createHash, randomBytes } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const NORMALIZED_INVITE_PATTERN = /^VG[A-Z0-9]{16}$/;

export function generateInviteCode(): string {
  const bytes = randomBytes(16);
  const body = Array.from(bytes, (byte) => INVITE_ALPHABET[byte % INVITE_ALPHABET.length]).join("");
  return `VG-${body.slice(0, 8)}-${body.slice(8)}`;
}

export function normalizeInviteCode(input: unknown): string {
  if (typeof input !== "string") {
    throw new HttpsError("invalid-argument", "Invite code is required.");
  }

  const normalized = input.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (!NORMALIZED_INVITE_PATTERN.test(normalized)) {
    throw new HttpsError("invalid-argument", "Invalid invite code.");
  }

  return normalized;
}

export function formatInviteCode(normalizedCode: string): string {
  if (!NORMALIZED_INVITE_PATTERN.test(normalizedCode)) {
    throw new HttpsError("invalid-argument", "Invalid invite code.");
  }

  return `VG-${normalizedCode.slice(2, 10)}-${normalizedCode.slice(10)}`;
}

export function hashInviteCode(normalizedCode: string): string {
  if (!NORMALIZED_INVITE_PATTERN.test(normalizedCode)) {
    throw new HttpsError("invalid-argument", "Invalid invite code.");
  }

  return createHash("sha256").update(normalizedCode).digest("hex");
}
