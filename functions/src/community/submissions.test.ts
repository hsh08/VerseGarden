import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";
import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  Timestamp,
  type DocumentReference,
  type Firestore
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { submitCommunityQTCore } from "./submissions.js";
import type { CallableAuth, MembershipStatus } from "./types.js";

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "versegarden-rules-test";

const ids = {
  platformAdmin: "platformAdminUid",
  communityAdminA: "communityAdminAUid",
  leaderA: "leaderAUid",
  memberA: "memberAUid",
  memberWithoutName: "memberWithoutNameUid",
  memberB: "memberBUid",
  removedMember: "removedMemberUid",
  bannedMember: "bannedMemberUid",
  leftMember: "leftMemberUid",
  malformedRoleMember: "malformedRoleMemberUid",
  nonMember: "nonMemberUid"
};

const communityA = "communityA";
const communityB = "communityB";
const inactiveCommunity = "inactiveCommunity";
const fixedTimestamp = Timestamp.fromDate(new Date("2026-08-24T00:00:00.000Z"));
const publishedDateKey = "2026-08-24";

let db: Firestore;

test.before(async () => {
  const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT }, "submission-functions-test");
  db = getFirestore(app);
});

test.after(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

test.beforeEach(async () => {
  await clearRootCollection("communities");
  await clearRootCollection("dailyQuietTimes");
  await seedFixtures();
});

function auth(uid: string, token: Record<string, unknown> = {}): NonNullable<CallableAuth> {
  return { uid, token };
}

function communityDoc(communityId: string) {
  return db.collection("communities").doc(communityId);
}

function memberDoc(communityId: string, uid: string) {
  return communityDoc(communityId).collection("members").doc(uid);
}

function communityQTDoc(communityId: string, dateKey: string) {
  return communityDoc(communityId).collection("dailyQuietTimes").doc(dateKey);
}

function submissionsCollection(communityId = communityA) {
  return communityDoc(communityId).collection("qtSubmissions");
}

function validCommunity(overrides: Record<string, unknown> = {}) {
  return {
    name: "VerseGarden Community",
    status: "active",
    timezone: "Asia/Seoul",
    memberCount: 1,
    createdBy: ids.platformAdmin,
    updatedBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validMembership(
  uid: string,
  role = "member",
  status: MembershipStatus = "active",
  overrides: Record<string, unknown> = {}
) {
  return {
    uid,
    role,
    status,
    displayName: `사용자 ${uid}`,
    joinedAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validCommunityQT(
  communityId: string,
  dateKey: string,
  status = "published",
  overrides: Record<string, unknown> = {}
) {
  return {
    communityId,
    dateKey,
    status,
    version: 3,
    ...overrides
  };
}

function validInput(overrides: Record<string, unknown> = {}) {
  return {
    communityId: communityA,
    dateKey: publishedDateKey,
    contentId: publishedDateKey,
    contentVersion: 2,
    reflectionAnswer: "말씀을 통해 받은 마음",
    applicationText: "오늘 실천할 한 가지",
    ...overrides
  };
}

async function seedFixtures() {
  await communityDoc(communityA).set(validCommunity({ name: "Community A" }));
  await communityDoc(communityB).set(validCommunity({ name: "Community B" }));
  await communityDoc(inactiveCommunity).set(validCommunity({
    name: "Inactive Community",
    status: "inactive"
  }));

  await memberDoc(communityA, ids.communityAdminA).set(
    validMembership(ids.communityAdminA, "admin")
  );
  await memberDoc(communityA, ids.leaderA).set(validMembership(ids.leaderA, "leader"));
  await memberDoc(communityA, ids.memberA).set(validMembership(
    ids.memberA,
    "member",
    "active",
    { displayName: "멤버 A" }
  ));
  await memberDoc(communityA, ids.memberWithoutName).set(validMembership(
    ids.memberWithoutName,
    "member",
    "active",
    { displayName: "" }
  ));
  await memberDoc(communityA, ids.removedMember).set(
    validMembership(ids.removedMember, "member", "removed")
  );
  await memberDoc(communityA, ids.bannedMember).set(
    validMembership(ids.bannedMember, "member", "banned")
  );
  await memberDoc(communityA, ids.leftMember).set(
    validMembership(ids.leftMember, "member", "left")
  );
  await memberDoc(communityA, ids.malformedRoleMember).set(
    validMembership(ids.malformedRoleMember, "root")
  );
  await memberDoc(communityB, ids.memberB).set(validMembership(ids.memberB));
  await memberDoc(inactiveCommunity, ids.memberA).set(validMembership(ids.memberA));

  await communityQTDoc(communityA, publishedDateKey).set(
    validCommunityQT(communityA, publishedDateKey)
  );
  await communityQTDoc(communityA, "2026-08-25").set(
    validCommunityQT(communityA, "2026-08-25", "draft")
  );
  await communityQTDoc(communityA, "2026-08-26").set(
    validCommunityQT(communityA, "2026-08-26", "archived")
  );
  await communityQTDoc(communityB, publishedDateKey).set(
    validCommunityQT(communityB, publishedDateKey)
  );
  await communityQTDoc(inactiveCommunity, publishedDateKey).set(
    validCommunityQT(inactiveCommunity, publishedDateKey)
  );
  await db.collection("dailyQuietTimes").doc("2026-08-27").set({
    dateKey: "2026-08-27",
    status: "published",
    version: 1
  });
}

async function clearRootCollection(collectionName: string) {
  const snapshot = await db.collection(collectionName).get();
  await Promise.all(snapshot.docs.map((doc) => deleteDocRecursive(doc.ref)));
}

async function deleteDocRecursive(ref: DocumentReference) {
  const collections = await ref.listCollections();
  for (const collection of collections) {
    const snapshot = await collection.get();
    await Promise.all(snapshot.docs.map((doc) => deleteDocRecursive(doc.ref)));
  }
  await ref.delete();
}

async function assertRejectsCode(action: () => Promise<unknown>, code: HttpsError["code"]) {
  await assert.rejects(action, (error) => {
    assert.ok(error instanceof HttpsError);
    assert.equal(error.code, code);
    return true;
  });
}

function expectedSubmissionId(communityId: string, dateKey: string, uid: string): string {
  return createHash("sha256")
    .update(`${communityId}:${dateKey}:${uid}`, "utf8")
    .digest("hex");
}

test("active member submission stores only the approved Community projection", async () => {
  const result = await submitCommunityQTCore(db, auth(ids.memberA), validInput());
  const expectedId = expectedSubmissionId(communityA, publishedDateKey, ids.memberA);

  assert.equal(result.alreadySubmitted, false);
  assert.equal(result.submissionId, expectedId);

  const snapshot = await submissionsCollection().doc(expectedId).get();
  assert.ok(snapshot.exists);
  assert.deepEqual(Object.keys(snapshot.data() ?? {}).sort(), [
    "applicationText",
    "communityId",
    "completedAt",
    "contentId",
    "contentSource",
    "contentVersion",
    "dateKey",
    "displayName",
    "reflectionAnswer",
    "schemaVersion",
    "uid"
  ]);
  const submission = snapshot.data();
  assert.equal(submission?.uid, ids.memberA);
  assert.equal(submission?.displayName, "멤버 A");
  assert.equal(submission?.contentSource, "community");
  assert.equal(submission?.reflectionAnswer, "말씀을 통해 받은 마음");
  assert.equal(submission?.applicationText, "오늘 실천할 한 가지");
  assert.equal(submission?.completedAt instanceof Timestamp, true);
  assert.equal("prayerText" in (submission ?? {}), false);
  assert.equal("email" in (submission ?? {}), false);
});

test("active member, leader, and community admin roles may submit", async () => {
  for (const uid of [ids.memberA, ids.leaderA, ids.communityAdminA]) {
    const result = await submitCommunityQTCore(db, auth(uid), validInput());
    assert.equal(result.alreadySubmitted, false);
  }
  assert.equal((await submissionsCollection().get()).size, 3);
});

test("empty reflection and application answers remain valid explicit shared values", async () => {
  const result = await submitCommunityQTCore(db, auth(ids.memberA), validInput({
    reflectionAnswer: "  ",
    applicationText: ""
  }));
  const submission = (await submissionsCollection().doc(result.submissionId).get()).data();
  assert.equal(submission?.reflectionAnswer, "");
  assert.equal(submission?.applicationText, "");
});

test("signed-out, missing, inactive, and malformed memberships are denied", async () => {
  await assertRejectsCode(() => submitCommunityQTCore(db, null, validInput()), "unauthenticated");
  for (const uid of [
    ids.nonMember,
    ids.removedMember,
    ids.bannedMember,
    ids.leftMember,
    ids.malformedRoleMember
  ]) {
    await assertRejectsCode(
      () => submitCommunityQTCore(db, auth(uid), validInput()),
      "permission-denied"
    );
  }
});

test("inactive community and cross-community submission are denied", async () => {
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      communityId: inactiveCommunity
    })),
    "failed-precondition"
  );
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      communityId: communityB
    })),
    "permission-denied"
  );
});

test("only an existing published Community QT can be submitted", async () => {
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      dateKey: "2026-08-23",
      contentId: "2026-08-23"
    })),
    "not-found"
  );
  for (const dateKey of ["2026-08-25", "2026-08-26"]) {
    await assertRejectsCode(
      () => submitCommunityQTCore(db, auth(ids.memberA), validInput({ dateKey, contentId: dateKey })),
      "failed-precondition"
    );
  }
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      dateKey: "2026-08-27",
      contentId: "2026-08-27"
    })),
    "not-found"
  );
});

test("content identity and version validation reject mismatches while allowing older valid versions", async () => {
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({ contentId: "wrong-content" })),
    "failed-precondition"
  );
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({ contentVersion: 4 })),
    "failed-precondition"
  );
  for (const contentVersion of [0, -1, 1.5]) {
    await assertRejectsCode(
      () => submitCommunityQTCore(db, auth(ids.memberA), validInput({ contentVersion })),
      "invalid-argument"
    );
  }
  const result = await submitCommunityQTCore(
    db,
    auth(ids.memberA),
    validInput({ contentVersion: 1 })
  );
  assert.equal(result.contentVersion, 1);
});

test("answer types, limits, date keys, and unknown or private fields are rejected", async () => {
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({ reflectionAnswer: 42 })),
    "invalid-argument"
  );
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      applicationText: "a".repeat(20_001)
    })),
    "invalid-argument"
  );
  await assertRejectsCode(
    () => submitCommunityQTCore(db, auth(ids.memberA), validInput({
      dateKey: "2026-02-30",
      contentId: "2026-02-30"
    })),
    "invalid-argument"
  );
  for (const fieldName of [
    "prayerText",
    "uid",
    "displayName",
    "completedAt",
    "submissionId",
    "unknown"
  ]) {
    await assertRejectsCode(
      () => submitCommunityQTCore(db, auth(ids.memberA), {
        ...validInput(),
        [fieldName]: "client supplied"
      }),
      "invalid-argument"
    );
  }
});

test("duplicate retry is idempotent and never overwrites the first submission", async () => {
  const first = await submitCommunityQTCore(db, auth(ids.memberA), validInput({
    contentVersion: 1,
    reflectionAnswer: "first reflection",
    applicationText: "first application"
  }));
  const before = (await submissionsCollection().doc(first.submissionId).get()).data();

  const second = await submitCommunityQTCore(db, auth(ids.memberA), validInput({
    contentVersion: 3,
    reflectionAnswer: "changed reflection",
    applicationText: "changed application"
  }));
  const after = (await submissionsCollection().doc(first.submissionId).get()).data();

  assert.equal(second.alreadySubmitted, true);
  assert.equal(second.submissionId, first.submissionId);
  assert.equal(second.contentVersion, 1);
  assert.equal((await submissionsCollection().get()).size, 1);
  assert.equal(after?.reflectionAnswer, "first reflection");
  assert.equal(after?.applicationText, "first application");
  assert.equal(after?.contentVersion, 1);
  assert.equal(
    (after?.completedAt as Timestamp).toMillis(),
    (before?.completedAt as Timestamp).toMillis()
  );

  await communityQTDoc(communityA, publishedDateKey).update({ status: "archived" });
  const archivedRetry = await submitCommunityQTCore(db, auth(ids.memberA), validInput());
  assert.equal(archivedRetry.alreadySubmitted, true);
  assert.equal((await submissionsCollection().get()).size, 1);
});

test("membership display name is server-derived with a safe UID fallback", async () => {
  const result = await submitCommunityQTCore(db, auth(ids.memberWithoutName), validInput());
  const submission = (await submissionsCollection().doc(result.submissionId).get()).data();
  assert.equal(submission?.displayName, `사용자 ${ids.memberWithoutName.slice(0, 8)}`);
});
