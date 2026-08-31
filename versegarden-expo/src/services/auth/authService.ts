import { FirebaseError } from "firebase/app";
import { onAuthStateChanged, sendPasswordResetEmail, signInWithEmailAndPassword, signOut, createUserWithEmailAndPassword, type User } from "firebase/auth";

import { getFirebaseServices } from "@/services/firebase";

function configuredAuth() {
  const services = getFirebaseServices();
  if (!services) throw new Error("Firebase configuration is unavailable.");
  return services.auth;
}

function logSignInFailure(error: unknown) {
  if (!__DEV__) return;

  const firebaseError = error instanceof FirebaseError ? error : null;
  console.error("[Firebase Auth] signInWithEmailAndPassword failed", {
    name: error instanceof Error ? error.name : "UnknownError",
    code: firebaseError?.code ?? "unknown",
    message: error instanceof Error ? error.message : "Unknown Firebase Auth error",
  });
}

export const authService = {
  observe: (listener: (user: User | null) => void) => onAuthStateChanged(configuredAuth(), listener),
  signIn: async (email: string, password: string) => {
    try {
      return await signInWithEmailAndPassword(configuredAuth(), email.trim(), password);
    } catch (error) {
      logSignInFailure(error);
      throw error;
    }
  },
  signUp: (email: string, password: string) => createUserWithEmailAndPassword(configuredAuth(), email.trim(), password),
  sendPasswordReset: (email: string) => sendPasswordResetEmail(configuredAuth(), email.trim()),
  signOut: () => signOut(configuredAuth()),
};
