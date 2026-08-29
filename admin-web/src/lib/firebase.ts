import { getApp, getApps, initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { connectFunctionsEmulator, getFunctions } from "firebase/functions";

declare global {
  var __verseGardenFunctionsEmulatorConnected: boolean | undefined;
}

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? "AIzaSyDUMMY_VERSEGARDEN_ADMIN_KEY",
  authDomain:
    process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? "versegarden-admin-placeholder.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? "versegarden-admin-placeholder",
  storageBucket:
    process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ??
    "versegarden-admin-placeholder.appspot.com",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID ?? "000000000000",
  appId:
    process.env.NEXT_PUBLIC_FIREBASE_APP_ID ??
    "1:000000000000:web:0000000000000000000000"
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(
  app,
  process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_REGION || "us-central1"
);

if (
  process.env.NEXT_PUBLIC_USE_FIREBASE_FUNCTIONS_EMULATOR === "true" &&
  !globalThis.__verseGardenFunctionsEmulatorConnected
) {
  connectFunctionsEmulator(
    functions,
    process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_EMULATOR_HOST || "127.0.0.1",
    Number(process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_EMULATOR_PORT || "5001")
  );
  globalThis.__verseGardenFunctionsEmulatorConnected = true;
}

export function hasFirebaseWebConfig(): boolean {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.authDomain &&
      firebaseConfig.projectId &&
      firebaseConfig.appId
  );
}
