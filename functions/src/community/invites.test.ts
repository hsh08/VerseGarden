import assert from "node:assert/strict";
import test from "node:test";
import { initializeApp, deleteApp, getApps } from "firebase-admin/app";
import { getFirestore, Timestamp, type DocumentReference, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import {
  createCommunityInviteCore,
  redeemCommunityInviteCore,
  regenerateCommunityInviteCore,
  revokeCommunityInviteCore
} from "./invites.js";
import { hashInviteCode, normalizeInviteCode } from "./inviteCodes.js";
import {
  getMyAdminCommunitiesCore,
  getMyCommunitiesCore,
  listManagedCommunityInvitesCore,
  setCommunityMemberRoleCore
} from "./roles.js";
import type { CallableAuth, CommunityInviteDoc, MembershipStatus } from "./types.js";

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "versegarden-rules-test";

const ids = {
  platformAdmin: "platformAdminUid",
  communityAdminA: "communityAdminAUid",
  secondaryAdminA: "secondaryAdminAUid",
  leaderA: "leaderAUid",
  multiCommunityAdmin: "multiCommunityAdminUid",
  memberA: "memberAUid",
  memberB: "memberBUid",
  removedMember: "removedMemberUid",
  bannedMember: "bannedMemberUid",
  leftMember: "leftMemberUid",
  nonMember: "nonMemberUid",
  nonMember2: "nonMember2Uid"
};

const communityA = "communityA";
const communityB = "communityB";
const inactiveCommunity = "inactiveCommunity";
const archivedCommunity = "archivedCommunity";
const inviteDisabledCommunity = "inviteDisabledCommunity";
const fixedTimestamp = Timestamp.fromDate(new Date("2026-08-24T00:00:00.000Z"));

let db: Firestore;

test.before(async () => {
  const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT }, "invite-functions-test");
  db = getFirestore(app);
});

test.after(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

test.beforeEach(async () => {
  await clearRootCollection("communities");
  await clearRootCollection("communityInvites");
  await clearRootCollection("users");
  await seedFixtures();
});

function auth(uid: string, token: Record<string, unknown> = {}): NonNullable<CallableAuth> {
  return { uid, token };
}

function platformAuth(): NonNullable<CallableAuth> {
  return auth(ids.platformAdmin, { admin: true });
}

function communityDoc(communityId: string) {
  return db.collection("communities").doc(communityId);
}

function memberDoc(communityId: string, uid: string) {
  return communityDoc(communityId).collection("members").doc(uid);
}

function validCommunity(overrides: Record<string, unknown> = {}) {
  return {
    name: "VerseGarden Community",
    description: "Synthetic test community",
    status: "active",
    timezone: "Asia/Seoul",
    primaryLeaderUid: ids.communityAdminA,
    inviteEnabled: true,
    memberCount: 0,
    createdBy: ids.platformAdmin,
    updatedBy: ids.platformAdmin,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
    ...overrides
  };
}

function validMembership(uid: string, role = "member", status: MembershipStatus = "active") {
  return {
    uid,
    role,
    status,
    displayName: uid,
    invitedBy: ids.platformAdmin,
    joinedAt: fixedTimestamp,
    updatedAt: fixedTimestamp
  };
}

async function seedFixtures() {
  await communityDoc(communityA).set(validCommunity({
    name: "Community A",
    primaryLeaderUid: ids.communityAdminA,
    memberCount: 5
  }));
  await communityDoc(communityB).set(validCommunity({
    name: "Community B",
    primaryLeaderUid: "communityAdminBUid",
    memberCount: 1
  }));
  await communityDoc(inactiveCommunity).set(validCommunity({
    name: "Inactive Community",
    status: "inactive"
  }));
  await communityDoc(archivedCommunity).set(validCommunity({
    name: "Archived Community",
    status: "archived"
  }));
  await communityDoc(inviteDisabledCommunity).set(validCommunity({
    name: "Invite Disabled Community",
    inviteEnabled: false
  }));

  await memberDoc(communityA, ids.communityAdminA).set(validMembership(ids.communityAdminA, "admin"));
  await memberDoc(communityA, ids.secondaryAdminA).set(validMembership(ids.secondaryAdminA, "admin"));
  await memberDoc(communityA, ids.leaderA).set(validMembership(ids.leaderA, "leader"));
  await memberDoc(communityA, ids.multiCommunityAdmin).set(validMembership(ids.multiCommunityAdmin, "admin"));
  await memberDoc(communityA, ids.memberA).set(validMembership(ids.memberA, "member"));
  await memberDoc(communityA, ids.removedMember).set(validMembership(ids.removedMember, "member", "removed"));
  await memberDoc(communityA, ids.bannedMember).set(validMembership(ids.bannedMember, "member", "banned"));
  await memberDoc(communityA, ids.leftMember).set(validMembership(ids.leftMember, "member", "left"));
  await memberDoc(communityB, "communityAdminBUid").set(validMembership("communityAdminBUid", "admin"));
  await memberDoc(communityB, ids.multiCommunityAdmin).set(validMembership(ids.multiCommunityAdmin, "leader"));
  await db.collection("users").doc(ids.nonMember).set({
    nickname: "새싹",
    displayName: "Fallback Name",
    email: "private@example.com"
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

async function createInvite(
  authInput: CallableAuth = platformAuth(),
  input: Record<string, unknown> = {}
) {
  return createCommunityInviteCore(db, authInput, {
    communityId: communityA,
    ...input
  });
}

async function getInviteByCode(code: string): Promise<CommunityInviteDoc> {
  const inviteId = hashInviteCode(normalizeInviteCode(code));
  const snapshot = await db.collection("communityInvites").doc(inviteId).get();
  assert.ok(snapshot.exists);
  return snapshot.data() as CommunityInviteDoc;
}

test("platform admin creates active hashed invites without storing plaintext code", async () => {
  const result = await createInvite(platformAuth(), {
    maxUses: 3,
    label: "Sunday group",
    expiresAt: "2099-01-01T00:00:00.000Z"
  });

  assert.match(result.code, /^VG-[A-Z0-9]{8}-[A-Z0-9]{8}$/);
  assert.equal(result.inviteId, hashInviteCode(normalizeInviteCode(result.code)));

  const snapshot = await db.collection("communityInvites").doc(result.inviteId).get();
  assert.ok(snapshot.exists);
  const invite = snapshot.data() as CommunityInviteDoc;
  assert.equal(invite.communityId, communityA);
  assert.equal(invite.status, "active");
  assert.equal(invite.useCount, 0);
  assert.equal(invite.maxUses, 3);
  assert.equal(invite.label, "Sunday group");
  assert.equal(invite.codeHash, result.inviteId);
  assert.equal(JSON.stringify(invite).includes(result.code), false);
});

test("community admin can create an invite for their own active community", async () => {
  const adminInvite = await createInvite(auth(ids.communityAdminA));

  assert.equal((await getInviteByCode(adminInvite.code)).createdBy, ids.communityAdminA);
});

test("leaders, members, non-members, signed-out users, and inactive communities cannot create invites", async () => {
  await assertRejectsCode(() => createInvite(auth(ids.leaderA)), "permission-denied");
  await assertRejectsCode(() => createInvite(auth(ids.memberA)), "permission-denied");
  await assertRejectsCode(() => createInvite(auth(ids.nonMember)), "permission-denied");
  await assertRejectsCode(() => createInvite(null), "unauthenticated");
  await assertRejectsCode(() => createInvite(platformAuth(), { communityId: inactiveCommunity }), "failed-precondition");
  await assertRejectsCode(() => createInvite(platformAuth(), { communityId: archivedCommunity }), "failed-precondition");
  await assertRejectsCode(() => createInvite(platformAuth(), { communityId: inviteDisabledCommunity }), "failed-precondition");
  await assertRejectsCode(() => createInvite(auth(ids.communityAdminA), { communityId: communityB }), "permission-denied");
});

test("redeem creates member membership, increments invite use count and community member count", async () => {
  const invite = await createInvite();
  const result = await redeemCommunityInviteCore(db, auth(ids.nonMember), { code: invite.code });

  assert.equal(result.communityId, communityA);
  assert.equal(result.alreadyMember, false);
  assert.equal(result.membershipStatus, "active");
  assert.equal(result.memberCount, 6);

  const membership = (await memberDoc(communityA, ids.nonMember).get()).data();
  assert.equal(membership?.role, "member");
  assert.equal(membership?.status, "active");
  assert.equal(membership?.displayName, "새싹");
  assert.equal("email" in (membership ?? {}), false);
  assert.equal((await getInviteByCode(invite.code)).useCount, 1);
  assert.equal((await communityDoc(communityA).get()).data()?.memberCount, 6);
});

test("duplicate redeem by active member is idempotent and does not increment counts", async () => {
  const invite = await createInvite();
  const beforeInvite = await getInviteByCode(invite.code);
  const beforeCommunity = (await communityDoc(communityA).get()).data();

  const result = await redeemCommunityInviteCore(db, auth(ids.memberA), { code: invite.code });

  assert.equal(result.alreadyMember, true);
  assert.equal((await getInviteByCode(invite.code)).useCount, beforeInvite.useCount);
  assert.equal((await communityDoc(communityA).get()).data()?.memberCount, beforeCommunity?.memberCount);
});

test("left member can rejoin while removed or banned members are denied", async () => {
  const invite = await createInvite();

  const rejoinResult = await redeemCommunityInviteCore(db, auth(ids.leftMember), { code: invite.code });
  assert.equal(rejoinResult.alreadyMember, false);
  assert.equal((await memberDoc(communityA, ids.leftMember).get()).data()?.status, "active");
  assert.equal((await getInviteByCode(invite.code)).useCount, 1);

  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.removedMember), { code: invite.code }), "permission-denied");
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.bannedMember), { code: invite.code }), "permission-denied");
});

test("redeem rejects invalid, revoked, expired, exhausted, and inactive-community invites", async () => {
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.nonMember), { code: "wrong" }), "invalid-argument");

  const revoked = await createInvite();
  await revokeCommunityInviteCore(db, platformAuth(), { code: revoked.code });
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.nonMember), { code: revoked.code }), "failed-precondition");

  const expired = await createInvite(platformAuth(), { expiresAt: "2000-01-01T00:00:00.000Z" });
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.nonMember), { code: expired.code }), "failed-precondition");

  const exhausted = await createInvite(platformAuth(), { maxUses: 1 });
  await redeemCommunityInviteCore(db, auth(ids.nonMember), { code: exhausted.code });
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.nonMember2), { code: exhausted.code }), "resource-exhausted");

  const inactive = await createCommunityInviteCore(db, platformAuth(), { communityId: communityA });
  await communityDoc(communityA).update({ status: "archived", updatedAt: Timestamp.now() });
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth("lateJoiner"), { code: inactive.code }), "failed-precondition");

  await communityDoc(communityA).update({ status: "active", inviteEnabled: true, updatedAt: Timestamp.now() });
  const disabled = await createCommunityInviteCore(db, platformAuth(), { communityId: communityA });
  await communityDoc(communityA).update({ inviteEnabled: false, updatedAt: Timestamp.now() });
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth("disabledJoiner"), { code: disabled.code }), "failed-precondition");
});

test("concurrent max-use redemption allows only one new member", async () => {
  const invite = await createInvite(platformAuth(), { maxUses: 1 });
  const results = await Promise.allSettled([
    redeemCommunityInviteCore(db, auth(ids.nonMember), { code: invite.code }),
    redeemCommunityInviteCore(db, auth(ids.nonMember2), { code: invite.code })
  ]);

  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);
  assert.equal((await getInviteByCode(invite.code)).useCount, 1);
});

test("revoke preserves invite document and prevents redemption", async () => {
  const invite = await createInvite();
  const revokeResult = await revokeCommunityInviteCore(db, auth(ids.communityAdminA), { code: invite.code });

  assert.equal(revokeResult.inviteId, invite.inviteId);
  assert.equal((await getInviteByCode(invite.code)).status, "revoked");
  await assertRejectsCode(() => redeemCommunityInviteCore(db, auth(ids.nonMember), { code: invite.code }), "failed-precondition");
});

test("only Platform Admin and Community Admin can revoke or regenerate invites", async () => {
  const invite = await createInvite();

  await assertRejectsCode(() => revokeCommunityInviteCore(db, auth(ids.leaderA), { code: invite.code }), "permission-denied");
  await assertRejectsCode(() => regenerateCommunityInviteCore(db, auth(ids.leaderA), { code: invite.code }), "permission-denied");
  await assertRejectsCode(() => revokeCommunityInviteCore(db, auth(ids.memberA), { code: invite.code }), "permission-denied");
  await assertRejectsCode(() => revokeCommunityInviteCore(db, auth(ids.nonMember), { code: invite.code }), "permission-denied");
  await assertRejectsCode(() => revokeCommunityInviteCore(db, null, { code: invite.code }), "unauthenticated");

  const regenerated = await regenerateCommunityInviteCore(db, auth(ids.communityAdminA), { code: invite.code });
  assert.notEqual(regenerated.inviteId, invite.inviteId);
  assert.equal((await getInviteByCode(invite.code)).status, "revoked");
  assert.equal((await getInviteByCode(regenerated.code)).status, "active");

  await communityDoc(communityA).update({ inviteEnabled: false, updatedAt: Timestamp.now() });
  await assertRejectsCode(
    () => regenerateCommunityInviteCore(db, platformAuth(), { code: regenerated.code }),
    "failed-precondition"
  );
  assert.equal((await getInviteByCode(regenerated.code)).status, "active");
});

test("platform admin changes member roles without mutating immutable membership fields", async () => {
  const memberRef = memberDoc(communityA, ids.memberA);
  const before = (await memberRef.get()).data();

  await setCommunityMemberRoleCore(db, platformAuth(), {
    communityId: communityA,
    targetUid: ids.memberA,
    role: "leader"
  });
  assert.equal((await memberRef.get()).data()?.role, "leader");

  await setCommunityMemberRoleCore(db, platformAuth(), {
    communityId: communityA,
    targetUid: ids.memberA,
    role: "admin"
  });
  const promoted = (await memberRef.get()).data();
  assert.equal(promoted?.role, "admin");
  assert.equal(promoted?.uid, before?.uid);
  assert.deepEqual(promoted?.joinedAt, before?.joinedAt);
  assert.equal(promoted?.invitedBy, before?.invitedBy);

  await setCommunityMemberRoleCore(db, platformAuth(), {
    communityId: communityA,
    targetUid: ids.secondaryAdminA,
    role: "member"
  });
  await setCommunityMemberRoleCore(db, platformAuth(), {
    communityId: communityA,
    targetUid: ids.leaderA,
    role: "member"
  });
  assert.equal((await memberDoc(communityA, ids.secondaryAdminA).get()).data()?.role, "member");
  assert.equal((await memberDoc(communityA, ids.leaderA).get()).data()?.role, "member");
});

test("community admin can change active member and leader roles in their own community", async () => {
  await setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
    communityId: communityA,
    targetUid: ids.memberA,
    role: "leader"
  });
  assert.equal((await memberDoc(communityA, ids.memberA).get()).data()?.role, "leader");

  await setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
    communityId: communityA,
    targetUid: ids.memberA,
    role: "member"
  });
  assert.equal((await memberDoc(communityA, ids.memberA).get()).data()?.role, "member");
});

test("community admin cannot grant admin, modify admins, self-manage, cross communities, or target missing members", async () => {
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
      communityId: communityA,
      targetUid: ids.memberA,
      role: "admin"
    }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
      communityId: communityA,
      targetUid: ids.secondaryAdminA,
      role: "member"
    }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
      communityId: communityA,
      targetUid: ids.communityAdminA,
      role: "leader"
    }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
      communityId: communityB,
      targetUid: "communityAdminBUid",
      role: "leader"
    }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, auth(ids.communityAdminA), {
      communityId: communityA,
      targetUid: "missing",
      role: "leader"
    }),
    "permission-denied"
  );
});

test("role mutation denies leaders, members, signed-out users, invalid inputs, and missing documents", async () => {
  const input = { communityId: communityA, targetUid: ids.memberA, role: "leader" };
  await assertRejectsCode(() => setCommunityMemberRoleCore(db, auth(ids.leaderA), input), "permission-denied");
  await assertRejectsCode(() => setCommunityMemberRoleCore(db, auth(ids.memberA), input), "permission-denied");
  await assertRejectsCode(() => setCommunityMemberRoleCore(db, null, input), "unauthenticated");
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, platformAuth(), { ...input, role: "root" }),
    "invalid-argument"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, platformAuth(), { ...input, communityId: "missing" }),
    "not-found"
  );
  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, platformAuth(), { ...input, targetUid: "missing" }),
    "not-found"
  );
});

test("inactive memberships cannot be promoted and primary leader cannot be downgraded to member", async () => {
  for (const targetUid of [ids.removedMember, ids.bannedMember, ids.leftMember]) {
    await assertRejectsCode(
      () => setCommunityMemberRoleCore(db, platformAuth(), {
        communityId: communityA,
        targetUid,
        role: "leader"
      }),
      "failed-precondition"
    );
  }

  await assertRejectsCode(
    () => setCommunityMemberRoleCore(db, platformAuth(), {
      communityId: communityA,
      targetUid: ids.communityAdminA,
      role: "member"
    }),
    "failed-precondition"
  );
  assert.equal((await memberDoc(communityA, ids.communityAdminA).get()).data()?.role, "admin");
});

test("admin scope lookup returns only active leader/admin memberships for the caller", async () => {
  const adminA = await getMyAdminCommunitiesCore(db, auth(ids.communityAdminA));
  assert.deepEqual(adminA.communities.map((item) => item.communityId), [communityA]);

  const multi = await getMyAdminCommunitiesCore(db, auth(ids.multiCommunityAdmin));
  assert.deepEqual(
    new Set(multi.communities.map((item) => item.communityId)),
    new Set([communityA, communityB])
  );

  assert.deepEqual((await getMyAdminCommunitiesCore(db, auth(ids.memberA))).communities, []);
  assert.deepEqual((await getMyAdminCommunitiesCore(db, auth(ids.removedMember))).communities, []);
  await assertRejectsCode(() => getMyAdminCommunitiesCore(db, null), "unauthenticated");
});

test("member community lookup returns only the caller's active memberships", async () => {
  const member = await getMyCommunitiesCore(db, auth(ids.memberA));
  assert.deepEqual(member.communities.map((item) => item.communityId), [communityA]);
  assert.equal(member.communities[0]?.role, "member");
  assert.equal(member.communities[0]?.membershipStatus, "active");
  assert.equal(member.communities[0]?.communityName, "Community A");
  assert.equal(member.communities[0]?.joinedAt, fixedTimestamp.toDate().toISOString());
  assert.equal(JSON.stringify(member).includes(ids.memberB), false);

  const leader = await getMyCommunitiesCore(db, auth(ids.leaderA));
  assert.deepEqual(leader.communities.map((item) => item.communityId), [communityA]);
  assert.equal(leader.communities[0]?.role, "leader");

  const admin = await getMyCommunitiesCore(db, auth(ids.communityAdminA));
  assert.deepEqual(admin.communities.map((item) => item.communityId), [communityA]);
  assert.equal(admin.communities[0]?.role, "admin");

  const multiple = await getMyCommunitiesCore(db, auth(ids.multiCommunityAdmin));
  assert.deepEqual(
    new Set(multiple.communities.map((item) => item.communityId)),
    new Set([communityA, communityB])
  );
});

test("member community lookup excludes inactive membership states and requires auth", async () => {
  assert.deepEqual((await getMyCommunitiesCore(db, auth(ids.removedMember))).communities, []);
  assert.deepEqual((await getMyCommunitiesCore(db, auth(ids.bannedMember))).communities, []);
  assert.deepEqual((await getMyCommunitiesCore(db, auth(ids.leftMember))).communities, []);
  assert.deepEqual((await getMyCommunitiesCore(db, auth(ids.nonMember))).communities, []);
  await assertRejectsCode(() => getMyCommunitiesCore(db, null), "unauthenticated");
});

test("managed invite listing is scoped and never returns invite secrets", async () => {
  const created = await createInvite();
  const own = await listManagedCommunityInvitesCore(db, auth(ids.communityAdminA), {
    communityId: communityA
  });
  assert.equal(own.invites.some((invite) => invite.inviteId === created.inviteId), true);
  assert.equal(JSON.stringify(own).includes("codeHash"), false);
  assert.equal(JSON.stringify(own).includes(created.code), false);

  await assertRejectsCode(
    () => listManagedCommunityInvitesCore(db, auth(ids.communityAdminA), { communityId: communityB }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => listManagedCommunityInvitesCore(db, auth(ids.leaderA), { communityId: communityA }),
    "permission-denied"
  );
  await assertRejectsCode(
    () => listManagedCommunityInvitesCore(db, auth(ids.memberA), { communityId: communityA }),
    "permission-denied"
  );
  const platform = await listManagedCommunityInvitesCore(db, platformAuth(), { communityId: communityA });
  assert.equal(platform.invites.length >= 1, true);
});
