import { deleteApp, initializeApp } from "firebase/app";
import {
  getAuth,
  getIdTokenResult,
  signInWithEmailAndPassword,
  signOut
} from "firebase/auth";
import { getFunctions, httpsCallable } from "firebase/functions";

const PRODUCTION_PROJECT_ID = "versegarden-34e7a";
const PRODUCTION_REGION = "us-central1";

function requiredEnvironmentValue(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function firebaseConfigFromEnvironment() {
  return {
    apiKey: requiredEnvironmentValue("NEXT_PUBLIC_FIREBASE_API_KEY"),
    authDomain: requiredEnvironmentValue("NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN"),
    projectId: requiredEnvironmentValue("NEXT_PUBLIC_FIREBASE_PROJECT_ID"),
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId: requiredEnvironmentValue("NEXT_PUBLIC_FIREBASE_APP_ID")
  };
}

function safeError(error) {
  if (typeof error !== "object" || error === null) {
    return { code: "unknown", message: "Community invite redemption failed." };
  }

  const code = "code" in error ? String(error.code) : "unknown";
  const message = "message" in error
    ? String(error.message)
    : "Community invite redemption failed.";
  return { code, message };
}

async function main() {
  const config = firebaseConfigFromEnvironment();
  const region = process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_REGION || PRODUCTION_REGION;

  if (config.projectId !== PRODUCTION_PROJECT_ID) {
    throw new Error(`Refusing to run against unexpected Firebase project: ${config.projectId}`);
  }
  if (region !== PRODUCTION_REGION) {
    throw new Error(`Refusing to run against unexpected Functions region: ${region}`);
  }
  if (process.env.NEXT_PUBLIC_USE_FIREBASE_FUNCTIONS_EMULATOR === "true") {
    throw new Error("Refusing production QA while the Functions emulator is enabled.");
  }

  const email = requiredEnvironmentValue("VG_QA_EMAIL");
  const password = requiredEnvironmentValue("VG_QA_PASSWORD");
  const inviteCode = requiredEnvironmentValue("VG_COMMUNITY_INVITE_CODE");
  const expectedCommunityId = requiredEnvironmentValue("VG_QA_EXPECTED_COMMUNITY_ID");
  const verifyIdempotency = process.env.VG_QA_VERIFY_IDEMPOTENCY === "true";

  const app = initializeApp(config, `community-redeem-qa-${Date.now()}`);
  const auth = getAuth(app);

  try {
    const credential = await signInWithEmailAndPassword(auth, email, password);
    const tokenResult = await getIdTokenResult(credential.user, true);

    if (tokenResult.claims.admin === true) {
      throw new Error("Refusing to redeem with a Platform Admin account.");
    }

    const functions = getFunctions(app, region);
    const redeem = httpsCallable(functions, "redeemCommunityInvite");
    const firstResponse = await redeem({ code: inviteCode });
    const firstResult = firstResponse.data;

    if (
      typeof firstResult !== "object" ||
      firstResult === null ||
      firstResult.communityId !== expectedCommunityId
    ) {
      throw new Error("Callable returned an unexpected Community.");
    }

    const safeResult = {
      projectId: config.projectId,
      region,
      callable: "redeemCommunityInvite",
      uid: credential.user.uid,
      adminClaim: false,
      communityId: firstResult.communityId,
      membershipStatus: firstResult.membershipStatus,
      alreadyMember: firstResult.alreadyMember,
      memberCount: firstResult.memberCount
    };

    if (verifyIdempotency) {
      const secondResponse = await redeem({ code: inviteCode });
      const secondResult = secondResponse.data;
      safeResult.idempotency = {
        alreadyMember: secondResult?.alreadyMember === true,
        memberCountUnchanged: secondResult?.memberCount === firstResult.memberCount
      };
    }

    console.log(JSON.stringify(safeResult, null, 2));
  } finally {
    if (auth.currentUser) {
      await signOut(auth);
    }
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(JSON.stringify(safeError(error), null, 2));
  process.exitCode = 1;
});
