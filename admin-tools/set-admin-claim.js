#!/usr/bin/env node

const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");

const VALID_COMMANDS = new Set(["set", "remove", "check"]);
const DEFAULT_CREDENTIAL_PATH = path.join(__dirname, "credentials", "service-account.json");

function usage() {
  console.log(`
Usage:
  npm run admin:set -- <UID>
  npm run admin:remove -- <UID>
  npm run admin:check -- <UID>

Environment:
  TARGET_UID=<UID> may be used instead of the CLI argument.
  GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json is supported.

Default credential path:
  ${DEFAULT_CREDENTIAL_PATH}
`);
}

function getCommand() {
  const command = process.argv[2];
  if (!VALID_COMMANDS.has(command)) {
    usage();
    throw new Error("Invalid command. Use set, remove, or check.");
  }
  return command;
}

function getTargetUid() {
  const uid = process.argv[3] || process.env.TARGET_UID;
  if (!uid || uid.trim().length === 0) {
    usage();
    throw new Error("Missing Firebase Auth UID.");
  }
  return uid.trim();
}

function getCredentialPath() {
  const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || DEFAULT_CREDENTIAL_PATH;
  return path.resolve(credentialPath);
}

function initializeFirebaseAdmin() {
  const credentialPath = getCredentialPath();

  if (!fs.existsSync(credentialPath)) {
    throw new Error(
      `Service account JSON was not found at: ${credentialPath}\n` +
        "Download it from Firebase Console and place it there, or set GOOGLE_APPLICATION_CREDENTIALS."
    );
  }

  const serviceAccount = require(credentialPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

function formatClaims(claims) {
  return JSON.stringify(claims || {}, null, 2);
}

async function main() {
  const command = getCommand();
  const uid = getTargetUid();

  initializeFirebaseAdmin();

  const beforeUser = await admin.auth().getUser(uid);
  const existingClaims = beforeUser.customClaims || {};

  console.log("Current custom claims:");
  console.log(formatClaims(existingClaims));

  if (command === "check") {
    console.log(`admin claim is ${existingClaims.admin === true ? "enabled" : "disabled"} for UID: ${uid}`);
    return;
  }

  const nextClaims = { ...existingClaims };

  if (command === "set") {
    nextClaims.admin = true;
  }

  if (command === "remove") {
    delete nextClaims.admin;
  }

  await admin.auth().setCustomUserClaims(uid, nextClaims);

  const afterUser = await admin.auth().getUser(uid);
  const afterClaims = afterUser.customClaims || {};

  console.log("Updated custom claims:");
  console.log(formatClaims(afterClaims));

  if (command === "set" && afterClaims.admin !== true) {
    throw new Error("Verification failed: admin claim was not set.");
  }

  if (command === "remove" && afterClaims.admin === true) {
    throw new Error("Verification failed: admin claim was not removed.");
  }

  console.log(`Success: admin claim ${command === "set" ? "enabled" : "removed"} for UID: ${uid}`);
  console.log("The user must sign out and sign in again, or refresh their ID token, before rules see the change.");
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
