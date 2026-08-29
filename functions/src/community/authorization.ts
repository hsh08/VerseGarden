import type { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import type { CallableAuth, CommunityDoc, CommunityInviteDoc, MembershipDoc } from "./types.js";

export function requireAuth(auth: CallableAuth): NonNullable<CallableAuth> {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }

  return auth;
}

export function isPlatformAdmin(auth: NonNullable<CallableAuth>): boolean {
  return auth.token?.admin === true;
}

export function isCommunityInviteManager(membership: MembershipDoc | null): boolean {
  return membership?.status === "active" && membership.role === "admin";
}

export async function getCommunity(db: Firestore, communityId: string): Promise<CommunityDoc> {
  const snapshot = await db.collection("communities").doc(communityId).get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Community not found.");
  }

  return snapshot.data() as CommunityDoc;
}

function assertCommunityAcceptsInvites(community: CommunityDoc) {
  if (community.status !== "active") {
    throw new HttpsError("failed-precondition", "Community is not active.");
  }

  if (community.inviteEnabled === false) {
    throw new HttpsError("failed-precondition", "Community invites are disabled.");
  }
}

export async function getMembership(
  db: Firestore,
  communityId: string,
  uid: string
): Promise<MembershipDoc | null> {
  const snapshot = await db.collection("communities").doc(communityId).collection("members").doc(uid).get();
  if (!snapshot.exists) {
    return null;
  }

  return snapshot.data() as MembershipDoc;
}

export async function requireInviteManagementPermission(
  db: Firestore,
  authInput: CallableAuth,
  communityId: string
): Promise<{ auth: NonNullable<CallableAuth>; community: CommunityDoc }> {
  const auth = requireAuth(authInput);
  const community = await getCommunity(db, communityId);

  if (isPlatformAdmin(auth)) {
    assertCommunityAcceptsInvites(community);
    return { auth, community };
  }

  const membership = await getMembership(db, communityId, auth.uid);
  if (!isCommunityInviteManager(membership)) {
    throw new HttpsError("permission-denied", "You do not have permission to manage community invites.");
  }

  assertCommunityAcceptsInvites(community);
  return { auth, community };
}

export async function requireInvitePermissionForExistingInvite(
  db: Firestore,
  authInput: CallableAuth,
  invite: CommunityInviteDoc
): Promise<NonNullable<CallableAuth>> {
  const auth = requireAuth(authInput);
  const community = await getCommunity(db, invite.communityId);

  if (isPlatformAdmin(auth)) {
    return auth;
  }

  const membership = await getMembership(db, invite.communityId, auth.uid);
  if (!isCommunityInviteManager(membership)) {
    throw new HttpsError("permission-denied", "You do not have permission to manage community invites.");
  }
  if (community.status !== "active") {
    throw new HttpsError("failed-precondition", "Community is not active.");
  }

  return auth;
}
