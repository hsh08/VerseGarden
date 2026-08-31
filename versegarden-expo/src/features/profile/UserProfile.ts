import type { Timestamp } from "firebase/firestore";

export type UserProfile = {
  id: string;
  email: string;
  nickname: string;
  onboardingCompleted: boolean;
  favoriteVerse: string;
  favoriteVerseId: string | null;
  selectedWritingPlanId: string | null;
  selectedTopics: string[];
  createdAt: Date;
  updatedAt: Date;
};

export type UserProfileDocument = {
  uid?: unknown;
  email?: unknown;
  displayName?: unknown;
  nickname?: unknown;
  onboardingCompleted?: unknown;
  favoriteVerse?: unknown;
  favoriteVerseId?: unknown;
  selectedWritingPlanId?: unknown;
  selectedTopics?: unknown;
  createdAt?: unknown;
  updatedAt?: unknown;
};

export function dateFromFirestore(value: unknown, fallback: Date): Date {
  if (isTimestamp(value)) return value.toDate();
  return fallback;
}

function isTimestamp(value: unknown): value is Timestamp {
  return typeof value === "object" && value !== null && "toDate" in value && typeof value.toDate === "function";
}

export function normalizedOptionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
