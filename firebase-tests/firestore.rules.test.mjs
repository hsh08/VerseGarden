import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where
} from "firebase/firestore";

const projectId = "versegarden-rules-test";
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT ?? "8080");

const ids = {
  platformAdmin: "platformAdminUid",
  communityAdminA: "communityAdminAUid",
  communityAdminB: "communityAdminBUid",
  leaderA: "leaderAUid",
  memberA: "memberAUid",
  memberB: "memberBUid",
  removedMember: "removedMemberUid",
  bannedMember: "bannedMemberUid",
  leftMember: "leftMemberUid",
  nonMember: "nonMemberUid"
};

const communityA = "communityA";
const communityB = "communityB";
const fixedTimestamp = Timestamp.fromDate(new Date("2026-08-24T00:00:00.000Z"));

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: firestorePort,
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8")
    }
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedFixtures();
});

function dbFor(uid, claims = {}) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

function platformDb() {
  return dbFor(ids.platformAdmin, { admin: true });
}

function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedFixtures() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, "communities", communityA), validCommunity({
      name: "Community A",
      createdBy: ids.platformAdmin,
      updatedBy: ids.platformAdmin,
      primaryLeaderUid: ids.communityAdminA,
      memberCount: 6
    }));
    await setDoc(doc(db, "communities", communityB), validCommunity({
      name: "Community B",
      createdBy: ids.platformAdmin,
      updatedBy: ids.platformAdmin,
      primaryLeaderUid: ids.communityAdminB,
      memberCount: 2
    }));

    await setDoc(memberDoc(db, communityA, ids.communityAdminA), validMembership(ids.communityAdminA, "admin"));
    await setDoc(memberDoc(db, communityA, ids.leaderA), validMembership(ids.leaderA, "leader"));
    await setDoc(memberDoc(db, communityA, ids.memberA), validMembership(ids.memberA, "member"));
    await setDoc(memberDoc(db, communityA, ids.removedMember), validMembership(ids.removedMember, "member", "removed"));
    await setDoc(memberDoc(db, communityA, ids.bannedMember), validMembership(ids.bannedMember, "member", "banned"));
    await setDoc(memberDoc(db, communityA, ids.leftMember), validMembership(ids.leftMember, "member", "left"));
    await setDoc(memberDoc(db, communityB, ids.communityAdminB), validMembership(ids.communityAdminB, "admin"));
    await setDoc(memberDoc(db, communityB, ids.memberB), validMembership(ids.memberB, "member"));

    for (const uid of Object.values(ids)) {
      await setDoc(doc(db, "users", uid), {
        uid,
        email: `${uid}@example.invalid`,
        nickname: uid,
        onboardingCompleted: true,
        createdAt: fixedTimestamp,
        updatedAt: fixedTimestamp
      });
    }

    await setDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord"), {
      recordId: "privateQtRecord",
      date: fixedTimestamp,
      dateKey: "2026-08-24",
      reference: "요한복음 3:16",
      reflectionAnswer: "private fake reflection",
      applicationText: "private fake application",
      prayerText: "private fake prayer",
      createdAt: fixedTimestamp,
      updatedAt: fixedTimestamp
    });
    await setDoc(doc(db, "users", ids.memberA, "prayers", "privatePrayer"), {
      title: "Private fake prayer",
      bodyText: "private fake prayer body",
      createdAt: fixedTimestamp,
      updatedAt: fixedTimestamp
    });
    await setDoc(doc(db, "users", ids.memberA, "writingRecords", "privateWriting"), {
      localId: "privateWriting",
      ownerUserId: ids.memberA,
      date: fixedTimestamp,
      verseId: "요한복음-3-16",
      book: "요한복음",
      chapter: 3,
      verse: 16,
      originalText: "fake verse",
      userText: "private fake writing",
      completedAt: fixedTimestamp
    });
    await setDoc(doc(db, "users", ids.memberA, "verseLists", "privateVerseList"), {
      title: "Private Verse List",
      createdAt: fixedTimestamp,
      updatedAt: fixedTimestamp
    });
    await setDoc(doc(
      db,
      "users",
      ids.memberA,
      "verseLists",
      "privateVerseList",
      "items",
      "privateVerseItem"
    ), {
      verseId: "요한복음-3-16",
      createdAt: fixedTimestamp
    });

    await setDoc(doc(db, "dailyQuietTimes", "2026-08-24"), validDailyQuietTime("2026-08-24", "published"));
    await setDoc(doc(db, "dailyQuietTimes", "2026-08-25"), validDailyQuietTime("2026-08-25", "draft"));
    await setDoc(doc(db, "dailyQuietTimes", "2026-08-26"), validDailyQuietTime("2026-08-26", "archived"));
    await setDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24"), validCommunityDailyQuietTime(communityA, "2026-08-24", "published"));
    await setDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-25"), validCommunityDailyQuietTime(communityA, "2026-08-25", "draft"));
    await setDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-26"), validCommunityDailyQuietTime(communityA, "2026-08-26", "archived"));
    await setDoc(communityDailyQuietTimeDoc(db, communityB, "2026-08-24"), validCommunityDailyQuietTime(communityB, "2026-08-24", "published"));
    await setDoc(communityQTSubmissionDoc(db, communityA, "submissionA"), validCommunityQTSubmission(
      communityA,
      ids.memberA,
      "2026-08-24"
    ));
    await setDoc(communityQTSubmissionDoc(db, communityB, "submissionB"), validCommunityQTSubmission(
      communityB,
      ids.memberB,
      "2026-08-24"
    ));
    await setDoc(doc(db, "communityInvites", "a".repeat(64)), validCommunityInvite(communityA, "a".repeat(64)));
  });
}

function communityDoc(db, communityId) {
  return doc(db, "communities", communityId);
}

function memberDoc(db, communityId, uid) {
  return doc(db, "communities", communityId, "members", uid);
}

function communityDailyQuietTimeDoc(db, communityId, dateKey) {
  return doc(db, "communities", communityId, "dailyQuietTimes", dateKey);
}

function communityQTSubmissionDoc(db, communityId, submissionId) {
  return doc(db, "communities", communityId, "qtSubmissions", submissionId);
}

function validCommunity(overrides = {}) {
  return {
    name: "VerseGarden Community",
    description: "Synthetic test community",
    status: "active",
    timezone: "Asia/Seoul",
    primaryLeaderUid: ids.communityAdminA,
    inviteEnabled: true,
    memberCount: 1,
    createdBy: ids.platformAdmin,
    updatedBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validMembership(uid, role = "member", status = "active", overrides = {}) {
  return {
    uid,
    role,
    status,
    displayName: uid,
    invitedBy: ids.platformAdmin,
    joinedAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validDailyQuietTime(dateKey, status = "draft", overrides = {}) {
  return {
    dateKey,
    timezone: "Asia/Seoul",
    title: `QT ${dateKey}`,
    verseId: "요한복음-3-16",
    startVerseId: "요한복음-3-16",
    endVerseId: "요한복음-3-16",
    reference: "요한복음 3:16",
    translation: "KRV",
    devotionalText: "Synthetic devotional text",
    reflectionPrompt: "Synthetic reflection prompt",
    applicationPrompt: "Synthetic application prompt",
    prayerPrompt: "Synthetic prayer prompt",
    questions: [],
    status,
    version: 1,
    createdBy: ids.platformAdmin,
    updatedBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validCommunityDailyQuietTime(communityId, dateKey, status = "draft", overrides = {}) {
  return {
    ...validDailyQuietTime(dateKey, status),
    communityId,
    ...overrides
  };
}

function validCommunityQTSubmission(communityId, uid, dateKey, overrides = {}) {
  return {
    uid,
    displayName: uid,
    communityId,
    dateKey,
    contentId: dateKey,
    contentVersion: 1,
    contentSource: "community",
    reflectionAnswer: "Shared reflection",
    applicationText: "Shared application",
    completedAt: fixedTimestamp,
    schemaVersion: 1,
    ...overrides
  };
}

function validCommunityInvite(communityId, codeHash, overrides = {}) {
  return {
    communityId,
    codeHash,
    status: "active",
    createdBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    useCount: 0,
    ...overrides
  };
}

test("platform admin can create, read, update communities and manage membership", async () => {
  const db = platformDb();
  await assertSucceeds(setDoc(communityDoc(db, "communityCreatedByPlatform"), validCommunity({ name: "Created" })));
  await assertSucceeds(getDoc(communityDoc(db, communityA)));
  await assertSucceeds(getDoc(communityDoc(db, communityB)));
  await assertSucceeds(updateDoc(communityDoc(db, communityA), {
    description: "Updated by platform admin",
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(setDoc(memberDoc(db, communityA, "newMemberUid"), validMembership("newMemberUid", "member")));
  await assertSucceeds(updateDoc(memberDoc(db, communityA, ids.memberA), {
    role: "leader",
    status: "active",
    updatedAt: fixedTimestamp
  }));
});

test("platform admin writes are structurally validated and hard delete is denied", async () => {
  const db = platformDb();
  await assertFails(setDoc(communityDoc(db, "missingName"), {
    status: "active",
    timezone: "Asia/Seoul",
    createdBy: ids.platformAdmin,
    updatedBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp
  }));
  await assertFails(setDoc(communityDoc(db, "badStatus"), validCommunity({ status: "deleted" })));
  await assertFails(setDoc(communityDoc(db, "badTimestamp"), validCommunity({ createdAt: "not-a-timestamp" })));
  await assertFails(setDoc(communityDoc(db, "extraField"), validCommunity({ unsupported: true })));
  await assertFails(setDoc(communityDoc(db, "badMemberCount"), validCommunity({ memberCount: "1" })));
  await assertFails(deleteDoc(communityDoc(db, communityA)));
  await assertFails(setDoc(memberDoc(db, communityA, "badRoleUid"), validMembership("badRoleUid", "root")));
  await assertFails(setDoc(memberDoc(db, communityA, "uidMismatch"), validMembership("differentUid", "member")));
});

test("platform admin does not receive private user subcollection access", async () => {
  const db = platformDb();
  await assertFails(getDoc(doc(db, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord")));
});

test("community invites are trusted-backend managed and not client writable", async () => {
  const inviteDoc = doc(platformDb(), "communityInvites", "a".repeat(64));
  await assertSucceeds(getDoc(inviteDoc));
  await assertSucceeds(getDocs(collection(platformDb(), "communityInvites")));
  await assertFails(setDoc(doc(platformDb(), "communityInvites", "b".repeat(64)), validCommunityInvite(communityA, "b".repeat(64))));
  await assertFails(updateDoc(inviteDoc, { status: "revoked", updatedAt: fixedTimestamp }));
  await assertFails(deleteDoc(inviteDoc));

  for (const uid of [ids.communityAdminA, ids.leaderA, ids.memberA, ids.nonMember]) {
    const db = dbFor(uid);
    await assertFails(getDoc(doc(db, "communityInvites", "a".repeat(64))));
    await assertFails(getDocs(collection(db, "communityInvites")));
    await assertFails(setDoc(doc(db, "communityInvites", "c".repeat(64)), validCommunityInvite(communityA, "c".repeat(64))));
  }

  const anon = anonDb();
  await assertFails(getDoc(doc(anon, "communityInvites", "a".repeat(64))));
  await assertFails(setDoc(doc(anon, "communityInvites", "d".repeat(64)), validCommunityInvite(communityA, "d".repeat(64))));
});

test("community admin can read own community and own community membership metadata only", async () => {
  const db = dbFor(ids.communityAdminA);
  await assertSucceeds(getDoc(communityDoc(db, communityA)));
  await assertSucceeds(getDocs(collection(db, "communities", communityA, "members")));
  await assertFails(getDocs(collection(db, "communities")));
  await assertFails(getDoc(communityDoc(db, communityB)));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.communityAdminA), { role: "member", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(communityDoc(db, communityA), { description: "direct edit", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(memberDoc(db, communityB, ids.memberB), { role: "admin", updatedAt: fixedTimestamp }));
  await assertFails(setDoc(communityDoc(db, "forgedCommunity"), validCommunity({ createdBy: ids.communityAdminA })));
  await assertFails(deleteDoc(communityDoc(db, communityA)));
  await assertFails(updateDoc(doc(db, "dailyQuietTimes", "2026-08-24"), { title: "forged", updatedAt: fixedTimestamp }));
  await assertFails(getDocs(collection(db, "dailyQuietTimes")));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord")));
});

test("community admin cannot obtain platform authority through owner-writable user fields", async () => {
  const db = dbFor(ids.communityAdminA);
  await assertSucceeds(setDoc(doc(db, "users", ids.communityAdminA), { admin: true }, { merge: true }));
  await assertFails(setDoc(doc(db, "dailyQuietTimes", "2026-08-27"), validDailyQuietTime("2026-08-27")));
});

test("community leader has scoped administrative read permissions but no platform access", async () => {
  const db = dbFor(ids.leaderA);
  await assertSucceeds(getDoc(communityDoc(db, communityA)));
  await assertSucceeds(getDocs(collection(db, "communities", communityA, "members")));
  await assertFails(getDoc(communityDoc(db, communityB)));
  await assertFails(updateDoc(doc(db, "dailyQuietTimes", "2026-08-24"), { title: "leader edit", updatedAt: fixedTimestamp }));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord")));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.leaderA), { role: "admin", updatedAt: fixedTimestamp }));
});

test("active member can read own community and own membership only", async () => {
  const db = dbFor(ids.memberA);
  await assertSucceeds(getDoc(communityDoc(db, communityA)));
  await assertSucceeds(getDoc(memberDoc(db, communityA, ids.memberA)));
  await assertFails(getDoc(communityDoc(db, communityB)));
  await assertFails(getDocs(collection(db, "communities", communityA, "members")));
});

test("active member cannot forge membership, escalate role, change status, or modify others", async () => {
  const db = dbFor(ids.memberA);
  await assertFails(setDoc(memberDoc(db, communityA, "attackerCreated"), validMembership("attackerCreated", "member")));
  await assertFails(setDoc(memberDoc(db, communityB, ids.memberA), validMembership(ids.memberA, "member")));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.memberA), { role: "admin", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.memberA), { role: "leader", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.memberA), { status: "left", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.communityAdminA), { role: "member", updatedAt: fixedTimestamp }));
  await assertFails(setDoc(communityDoc(db, "memberCreatedCommunity"), validCommunity({ createdBy: ids.memberA })));
  await assertFails(updateDoc(communityDoc(db, communityA), { status: "archived", updatedAt: fixedTimestamp }));
  await assertFails(updateDoc(doc(db, "dailyQuietTimes", "2026-08-24"), { title: "member edit", updatedAt: fixedTimestamp }));
  await assertFails(getDoc(doc(db, "users", ids.memberB)));
});

test("inactive memberships are not treated as active members", async () => {
  for (const uid of [ids.removedMember, ids.bannedMember, ids.leftMember]) {
    const db = dbFor(uid);
    await assertFails(getDoc(communityDoc(db, communityA)));
    await assertFails(getDoc(memberDoc(db, communityA, uid)));
    await assertFails(updateDoc(memberDoc(db, communityA, uid), { status: "active", updatedAt: fixedTimestamp }));
  }
});

test("non-member cannot access community data or forge membership", async () => {
  const db = dbFor(ids.nonMember);
  await assertFails(getDoc(communityDoc(db, communityA)));
  await assertFails(getDocs(collection(db, "communities", communityA, "members")));
  await assertFails(setDoc(memberDoc(db, communityA, ids.nonMember), validMembership(ids.nonMember, "admin")));
  await assertFails(setDoc(memberDoc(db, communityA, "someoneElse"), validMembership("someoneElse", "member")));
  await assertFails(setDoc(communityDoc(db, "nonMemberCommunity"), validCommunity({ createdBy: ids.nonMember })));
  await assertFails(updateDoc(communityDoc(db, communityA), { description: "forged", updatedAt: fixedTimestamp }));
});

test("signed-out users cannot access protected community, membership, user, or global QT data", async () => {
  const db = anonDb();
  await assertFails(getDoc(communityDoc(db, communityA)));
  await assertFails(setDoc(communityDoc(db, "anonCommunity"), validCommunity({ createdBy: "anon" })));
  await assertFails(setDoc(memberDoc(db, communityA, "anon"), validMembership("anon", "member")));
  await assertFails(getDoc(doc(db, "users", ids.memberA)));
  await assertFails(getDoc(doc(db, "dailyQuietTimes", "2026-08-24")));
});

test("cross-community isolation is enforced for admins and members", async () => {
  await assertSucceeds(getDoc(communityDoc(dbFor(ids.communityAdminA), communityA)));
  await assertFails(getDoc(communityDoc(dbFor(ids.communityAdminA), communityB)));
  await assertSucceeds(getDoc(communityDoc(dbFor(ids.memberA), communityA)));
  await assertFails(getDoc(communityDoc(dbFor(ids.memberA), communityB)));
  await assertSucceeds(getDoc(communityDoc(dbFor(ids.communityAdminB), communityB)));
  await assertFails(getDoc(communityDoc(dbFor(ids.communityAdminB), communityA)));
  await assertSucceeds(getDoc(communityDoc(dbFor(ids.memberB), communityB)));
  await assertFails(getDoc(communityDoc(dbFor(ids.memberB), communityA)));
});

test("membership structural validation rejects invalid roles, statuses, uid mismatch, timestamp types, and extra fields", async () => {
  const db = platformDb();
  await assertFails(setDoc(memberDoc(db, communityA, "rootRole"), validMembership("rootRole", "root")));
  await assertFails(setDoc(memberDoc(db, communityA, "platformAdminRole"), validMembership("platformAdminRole", "platformAdmin")));
  await assertFails(setDoc(memberDoc(db, communityA, "unknownStatus"), validMembership("unknownStatus", "member", "unknown")));
  await assertFails(setDoc(memberDoc(db, communityA, "uidMismatch2"), validMembership("differentUid", "member")));
  await assertFails(setDoc(memberDoc(db, communityA, "badJoinedAt"), validMembership("badJoinedAt", "member", "active", { joinedAt: "not-a-timestamp" })));
  await assertFails(setDoc(memberDoc(db, communityA, "extraMembership"), validMembership("extraMembership", "member", "active", { unexpected: true })));
});

test("private user data remains owner-only", async () => {
  const memberA = dbFor(ids.memberA);
  await assertSucceeds(getDoc(doc(memberA, "users", ids.memberA)));
  await assertSucceeds(getDoc(doc(memberA, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertSucceeds(getDoc(doc(memberA, "users", ids.memberA, "qtRecords", "privateQtRecord")));
  await assertSucceeds(getDoc(doc(memberA, "users", ids.memberA, "writingRecords", "privateWriting")));
  await assertSucceeds(getDoc(doc(memberA, "users", ids.memberA, "verseLists", "privateVerseList")));
  await assertSucceeds(getDoc(doc(
    memberA,
    "users",
    ids.memberA,
    "verseLists",
    "privateVerseList",
    "items",
    "privateVerseItem"
  )));

  const memberB = dbFor(ids.memberB);
  await assertFails(getDoc(doc(memberB, "users", ids.memberA)));
  await assertFails(getDoc(doc(memberB, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertFails(getDoc(doc(memberB, "users", ids.memberA, "qtRecords", "privateQtRecord")));
  await assertFails(getDoc(doc(memberB, "users", ids.memberA, "writingRecords", "privateWriting")));
  await assertFails(getDoc(doc(memberB, "users", ids.memberA, "verseLists", "privateVerseList")));
  await assertFails(getDoc(doc(
    memberB,
    "users",
    ids.memberA,
    "verseLists",
    "privateVerseList",
    "items",
    "privateVerseItem"
  )));

  const communityAdminA = dbFor(ids.communityAdminA);
  await assertFails(getDoc(doc(communityAdminA, "users", ids.memberA, "prayers", "privatePrayer")));
  await assertFails(getDoc(doc(communityAdminA, "users", ids.memberA, "qtRecords", "privateQtRecord")));
  await assertFails(getDoc(doc(communityAdminA, "users", ids.memberA, "writingRecords", "privateWriting")));
  await assertFails(getDoc(doc(communityAdminA, "users", ids.memberA, "verseLists", "privateVerseList")));
  await assertFails(getDoc(doc(
    communityAdminA,
    "users",
    ids.memberA,
    "verseLists",
    "privateVerseList",
    "items",
    "privateVerseItem"
  )));
});

test("active Community Admin and Leader can read only their Community QT submissions", async () => {
  for (const uid of [ids.communityAdminA, ids.leaderA]) {
    const db = dbFor(uid);
    await assertSucceeds(getDoc(communityQTSubmissionDoc(db, communityA, "submissionA")));
    await assertSucceeds(getDocs(collection(db, "communities", communityA, "qtSubmissions")));
    await assertSucceeds(getDocs(query(
      collection(db, "communities", communityA, "qtSubmissions"),
      where("dateKey", "==", "2026-08-24")
    )));
    await assertSucceeds(getDocs(query(
      collection(db, "communities", communityA, "qtSubmissions"),
      orderBy("dateKey", "desc")
    )));
    await assertFails(getDoc(communityQTSubmissionDoc(db, communityB, "submissionB")));
    await assertFails(getDocs(collection(db, "communities", communityB, "qtSubmissions")));
  }
});

test("member, inactive membership, Platform claim alone, and signed-out users cannot read submissions", async () => {
  for (const uid of [ids.memberA, ids.removedMember, ids.bannedMember, ids.leftMember]) {
    const db = dbFor(uid);
    await assertFails(getDoc(communityQTSubmissionDoc(db, communityA, "submissionA")));
    await assertFails(getDocs(collection(db, "communities", communityA, "qtSubmissions")));
  }

  const platform = platformDb();
  await assertFails(getDoc(communityQTSubmissionDoc(platform, communityA, "submissionA")));
  await assertFails(getDocs(collection(platform, "communities", communityA, "qtSubmissions")));

  const anon = anonDb();
  await assertFails(getDoc(communityQTSubmissionDoc(anon, communityA, "submissionA")));
  await assertFails(getDocs(collection(anon, "communities", communityA, "qtSubmissions")));
});

test("all Community QT submission writes are trusted-backend only", async () => {
  for (const db of [
    platformDb(),
    dbFor(ids.communityAdminA),
    dbFor(ids.leaderA),
    dbFor(ids.memberA),
    anonDb()
  ]) {
    const existing = communityQTSubmissionDoc(db, communityA, "submissionA");
    const created = communityQTSubmissionDoc(db, communityA, "clientCreatedSubmission");
    await assertFails(setDoc(created, validCommunityQTSubmission(
      communityA,
      ids.memberA,
      "2026-08-25"
    )));
    await assertFails(updateDoc(existing, { reflectionAnswer: "Client overwrite" }));
    await assertFails(deleteDoc(existing));
  }
});

test("platform admin can manage Community QT for any community without hard delete", async () => {
  const db = platformDb();
  const created = communityDailyQuietTimeDoc(db, communityA, "2026-08-27");
  await assertSucceeds(setDoc(created, validCommunityDailyQuietTime(
    communityA,
    "2026-08-27",
    "draft",
    { createdBy: ids.platformAdmin, updatedBy: ids.platformAdmin }
  )));
  await assertSucceeds(getDoc(created));
  await assertSucceeds(getDocs(collection(db, "communities", communityA, "dailyQuietTimes")));
  await assertSucceeds(getDocs(collection(db, "communities", communityB, "dailyQuietTimes")));

  const draft = communityDailyQuietTimeDoc(db, communityA, "2026-08-25");
  await assertSucceeds(updateDoc(draft, {
    title: "Platform content update",
    version: 2,
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(updateDoc(draft, {
    status: "published",
    version: 2,
    publishedAt: fixedTimestamp,
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24"), {
    status: "archived",
    version: 1,
    archivedAt: fixedTimestamp,
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertFails(deleteDoc(created));
});

test("community admin can manage only own active Community QT", async () => {
  const db = dbFor(ids.communityAdminA);
  await assertSucceeds(getDocs(collection(db, "communities", communityA, "dailyQuietTimes")));
  await assertSucceeds(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-25")));
  await assertSucceeds(setDoc(
    communityDailyQuietTimeDoc(db, communityA, "2026-08-27"),
    validCommunityDailyQuietTime(communityA, "2026-08-27", "draft", {
      createdBy: ids.communityAdminA,
      updatedBy: ids.communityAdminA
    })
  ));
  await assertSucceeds(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-25"), {
    title: "Community admin content update",
    version: 2,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24"), {
    status: "archived",
    version: 1,
    archivedAt: fixedTimestamp,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));

  await assertFails(getDoc(communityDailyQuietTimeDoc(db, communityB, "2026-08-24")));
  await assertFails(getDocs(collection(db, "communities", communityB, "dailyQuietTimes")));
  await assertFails(setDoc(
    communityDailyQuietTimeDoc(db, communityB, "2026-08-27"),
    validCommunityDailyQuietTime(communityB, "2026-08-27", "draft", {
      createdBy: ids.communityAdminA,
      updatedBy: ids.communityAdminA
    })
  ));
  await assertFails(updateDoc(doc(db, "dailyQuietTimes", "2026-08-24"), {
    title: "Global edit denied",
    updatedAt: fixedTimestamp
  }));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord")));
});

test("leader can manage own active Community QT but not other or global QT", async () => {
  const db = dbFor(ids.leaderA);
  await assertSucceeds(getDocs(collection(db, "communities", communityA, "dailyQuietTimes")));
  await assertSucceeds(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-26")));
  await assertSucceeds(setDoc(
    communityDailyQuietTimeDoc(db, communityA, "2026-08-28"),
    validCommunityDailyQuietTime(communityA, "2026-08-28", "draft", {
      createdBy: ids.leaderA,
      updatedBy: ids.leaderA
    })
  ));
  await assertSucceeds(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-25"), {
    status: "published",
    version: 1,
    publishedAt: fixedTimestamp,
    updatedBy: ids.leaderA,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24"), {
    status: "archived",
    version: 1,
    archivedAt: fixedTimestamp,
    updatedBy: ids.leaderA,
    updatedAt: fixedTimestamp
  }));

  await assertFails(getDoc(communityDailyQuietTimeDoc(db, communityB, "2026-08-24")));
  await assertFails(getDocs(collection(db, "communities", communityB, "dailyQuietTimes")));
  await assertFails(updateDoc(doc(db, "dailyQuietTimes", "2026-08-24"), {
    title: "Global edit denied",
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(memberDoc(db, communityA, ids.memberA), {
    role: "leader",
    updatedAt: fixedTimestamp
  }));
  await assertFails(getDoc(doc(db, "users", ids.memberA, "qtRecords", "privateQtRecord")));
});

test("active member can direct-get only published QT from own active community", async () => {
  const db = dbFor(ids.memberA);
  await assertSucceeds(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24")));
  await assertFails(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-25")));
  await assertFails(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-26")));
  await assertFails(getDocs(collection(db, "communities", communityA, "dailyQuietTimes")));
  await assertFails(getDoc(communityDailyQuietTimeDoc(db, communityB, "2026-08-24")));
  await assertFails(setDoc(
    communityDailyQuietTimeDoc(db, communityA, "2026-08-27"),
    validCommunityDailyQuietTime(communityA, "2026-08-27", "draft", {
      createdBy: ids.memberA,
      updatedBy: ids.memberA
    })
  ));
  await assertFails(updateDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24"), {
    status: "archived",
    version: 1,
    updatedBy: ids.memberA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(deleteDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24")));
});

test("inactive memberships and signed-out users cannot read Community QT", async () => {
  for (const uid of [ids.removedMember, ids.bannedMember, ids.leftMember]) {
    await assertFails(getDoc(communityDailyQuietTimeDoc(
      dbFor(uid),
      communityA,
      "2026-08-24"
    )));
  }

  const anon = anonDb();
  await assertFails(getDoc(communityDailyQuietTimeDoc(anon, communityA, "2026-08-24")));
  await assertFails(getDocs(collection(anon, "communities", communityA, "dailyQuietTimes")));
  await assertFails(setDoc(
    communityDailyQuietTimeDoc(anon, communityA, "2026-08-27"),
    validCommunityDailyQuietTime(communityA, "2026-08-27")
  ));
});

test("inactive and archived communities expose read-only QT history to managers", async () => {
  const platform = platformDb();
  const communityAdmin = dbFor(ids.communityAdminA);
  const leader = dbFor(ids.leaderA);
  const member = dbFor(ids.memberA);

  await assertSucceeds(updateDoc(communityDoc(platform, communityA), {
    status: "inactive",
    inviteEnabled: false,
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  for (const db of [platform, communityAdmin, leader]) {
    await assertSucceeds(getDoc(communityDailyQuietTimeDoc(db, communityA, "2026-08-24")));
    await assertSucceeds(getDocs(collection(db, "communities", communityA, "dailyQuietTimes")));
  }
  await assertFails(getDoc(communityDailyQuietTimeDoc(member, communityA, "2026-08-24")));
  await assertFails(setDoc(
    communityDailyQuietTimeDoc(platform, communityA, "2026-08-27"),
    validCommunityDailyQuietTime(communityA, "2026-08-27")
  ));
  await assertFails(updateDoc(communityDailyQuietTimeDoc(communityAdmin, communityA, "2026-08-25"), {
    status: "published",
    version: 1,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));

  await assertSucceeds(updateDoc(communityDoc(platform, communityA), {
    status: "archived",
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(getDoc(communityDailyQuietTimeDoc(platform, communityA, "2026-08-24")));
  await assertSucceeds(getDoc(communityDailyQuietTimeDoc(leader, communityA, "2026-08-24")));
  await assertFails(updateDoc(communityDailyQuietTimeDoc(leader, communityA, "2026-08-25"), {
    title: "Archived edit denied",
    version: 2,
    updatedBy: ids.leaderA,
    updatedAt: fixedTimestamp
  }));
});

test("Community QT shape, identity, immutable fields, and version policy are enforced", async () => {
  const db = dbFor(ids.communityAdminA);
  const createRef = communityDailyQuietTimeDoc(db, communityA, "2026-08-27");

  await assertFails(setDoc(createRef, validCommunityDailyQuietTime(
    communityB,
    "2026-08-27",
    "draft",
    { createdBy: ids.communityAdminA, updatedBy: ids.communityAdminA }
  )));
  await assertFails(setDoc(createRef, validCommunityDailyQuietTime(
    communityA,
    "2026-08-26",
    "draft",
    { createdBy: ids.communityAdminA, updatedBy: ids.communityAdminA }
  )));
  await assertFails(setDoc(createRef, validCommunityDailyQuietTime(
    communityA,
    "2026-08-27",
    "draft",
    { version: 2, createdBy: ids.communityAdminA, updatedBy: ids.communityAdminA }
  )));
  await assertFails(setDoc(createRef, validCommunityDailyQuietTime(
    communityA,
    "2026-08-27",
    "draft",
    { createdBy: ids.platformAdmin, updatedBy: ids.communityAdminA }
  )));
  await assertFails(setDoc(createRef, validCommunityDailyQuietTime(
    communityA,
    "2026-08-27",
    "draft",
    { createdBy: ids.communityAdminA, updatedBy: ids.communityAdminA, unexpected: true }
  )));

  const draft = communityDailyQuietTimeDoc(db, communityA, "2026-08-25");
  await assertFails(updateDoc(draft, {
    title: "Changed without version",
    version: 1,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    status: "published",
    version: 2,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    communityId: communityB,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    timezone: "UTC",
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    createdBy: ids.communityAdminA,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    updatedBy: ids.platformAdmin,
    updatedAt: fixedTimestamp
  }));
  await assertSucceeds(updateDoc(draft, {
    title: "Changed with version",
    version: 2,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
  await assertFails(updateDoc(draft, {
    title: "Version rollback",
    version: 1,
    updatedBy: ids.communityAdminA,
    updatedAt: fixedTimestamp
  }));
});

test("global Daily QT existing access model is preserved", async () => {
  const memberA = dbFor(ids.memberA);
  await assertSucceeds(getDoc(doc(memberA, "dailyQuietTimes", "2026-08-24")));
  await assertFails(getDoc(doc(memberA, "dailyQuietTimes", "2026-08-25")));
  await assertFails(getDoc(doc(memberA, "dailyQuietTimes", "2026-08-26")));
  await assertFails(setDoc(doc(memberA, "dailyQuietTimes", "2026-08-27"), validDailyQuietTime("2026-08-27")));
  await assertFails(updateDoc(doc(memberA, "dailyQuietTimes", "2026-08-24"), { title: "member edit", updatedAt: fixedTimestamp }));

  const communityAdminA = dbFor(ids.communityAdminA);
  await assertSucceeds(getDoc(doc(communityAdminA, "dailyQuietTimes", "2026-08-24")));
  await assertFails(setDoc(doc(communityAdminA, "dailyQuietTimes", "2026-08-28"), validDailyQuietTime("2026-08-28")));

  const platform = platformDb();
  await assertSucceeds(getDoc(doc(platform, "dailyQuietTimes", "2026-08-25")));
  await assertSucceeds(getDocs(collection(platform, "dailyQuietTimes")));
  await assertSucceeds(setDoc(doc(platform, "dailyQuietTimes", "2026-08-29"), validDailyQuietTime("2026-08-29")));
  await assertSucceeds(updateDoc(doc(platform, "dailyQuietTimes", "2026-08-24"), { title: "platform edit", updatedAt: fixedTimestamp }));
});

test("collection list/query permissions are distinct from document get permissions", async () => {
  await assertSucceeds(getDocs(collection(platformDb(), "communities")));
  await assertFails(getDocs(collection(dbFor(ids.communityAdminA), "communities")));
  await assertFails(getDocs(collection(dbFor(ids.memberA), "communities")));
  await assertSucceeds(getDocs(collection(dbFor(ids.communityAdminA), "communities", communityA, "members")));
  await assertFails(getDocs(collection(dbFor(ids.memberA), "communities", communityA, "members")));
  await assertSucceeds(getDocs(collection(platformDb(), "dailyQuietTimes")));
  await assertFails(getDocs(collection(dbFor(ids.memberA), "dailyQuietTimes")));
});

test("test harness is using the isolated emulator project", () => {
  assert.equal(projectId, "versegarden-rules-test");
});
