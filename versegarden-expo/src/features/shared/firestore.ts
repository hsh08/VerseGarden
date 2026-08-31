import type { Timestamp } from "firebase/firestore";

import { getFirebaseServices } from "@/services/firebase";

export function requireCurrentUserID(): string {
  const userID = getFirebaseServices()?.auth.currentUser?.uid;
  if (!userID) throw new Error("not-authenticated");
  return userID;
}

export function requireFirestore() {
  const firestore = getFirebaseServices()?.firestore;
  if (!firestore) throw new Error("firebase-unavailable");
  return firestore;
}

export function firestoreDate(value: unknown, fallback: Date | null = null): Date | null {
  if (isTimestamp(value)) return value.toDate();
  return fallback;
}

export function isTimestamp(value: unknown): value is Timestamp {
  return typeof value === "object" && value !== null && "toDate" in value && typeof value.toDate === "function";
}

export function createLocalID(): string {
  const randomUUID = globalThis.crypto?.randomUUID?.bind(globalThis.crypto);
  if (randomUUID) return randomUUID();

  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (character) => {
    const random = Math.floor(Math.random() * 16);
    const value = character === "x" ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
}

export function personalErrorMessage(error: unknown, fallback: string): string {
  const code = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
  if (code.includes("permission-denied")) return "권한을 확인할 수 없습니다. 다시 로그인한 뒤 시도해주세요.";
  if (code.includes("unavailable") || code.includes("network")) return "네트워크를 확인한 뒤 다시 시도해주세요.";
  return fallback;
}
