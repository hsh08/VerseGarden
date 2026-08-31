import AsyncStorage from "@react-native-async-storage/async-storage";
import { getApp, getApps, initializeApp, type FirebaseApp } from "firebase/app";
import * as FirebaseAuth from "firebase/auth";
import { getAuth, initializeAuth, type Auth, type Persistence } from "firebase/auth";
import { getFirestore, type Firestore } from "firebase/firestore";
import { getFunctions, type Functions } from "firebase/functions";

import { firebaseEnvironment } from "./config";

export type FirebaseServices = { app: FirebaseApp; auth: Auth; firestore: Firestore; functions: Functions };

let services: FirebaseServices | null = null;
let hasLoggedConfigDiagnostics = false;

type ReactNativeAuthModule = typeof FirebaseAuth & {
  getReactNativePersistence(storage: typeof AsyncStorage): Persistence;
};

// Metro selects Firebase Auth's React Native entry point. Its conditional type export is not
// exposed through firebase/auth's TypeScript facade, so keep this narrow runtime bridge here.
const { getReactNativePersistence } = FirebaseAuth as ReactNativeAuthModule;

function logConfigDiagnostics() {
  if (!__DEV__ || hasLoggedConfigDiagnostics) return;

  hasLoggedConfigDiagnostics = true;
  const { apiKey, appId, authDomain, projectId } = firebaseEnvironment.config;
  console.info("[Firebase Config Diagnostics]", {
    apiKeyPresent: Boolean(apiKey),
    apiKeyLength: apiKey.trim().length,
    apiKeyLooksLikeFirebaseKey: /^AIza[\w-]{20,}$/.test(apiKey.trim()),
    authDomainPresent: Boolean(authDomain),
    projectIdPresent: Boolean(projectId),
    appIdPresent: Boolean(appId),
  });
}

export function getFirebaseServices(): FirebaseServices | null {
  logConfigDiagnostics();
  if (!firebaseEnvironment.isConfigured) {
    if (__DEV__) console.info("[Firebase] initialized", { app: false, auth: false });
    return null;
  }
  if (services) return services;

  const app = getApps().length ? getApp() : initializeApp(firebaseEnvironment.config);
  let auth: Auth;
  try {
    auth = initializeAuth(app, { persistence: getReactNativePersistence(AsyncStorage) });
  } catch {
    // Fast Refresh can preserve a Firebase Auth instance while re-evaluating this module.
    auth = getAuth(app);
  }

  services = {
    app,
    auth,
    firestore: getFirestore(app),
    functions: getFunctions(app, firebaseEnvironment.functionsRegion),
  };
  if (__DEV__) console.info("[Firebase] initialized", { app: true, auth: true });
  return services;
}
