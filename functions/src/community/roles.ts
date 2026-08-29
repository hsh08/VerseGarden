import { getFirestore, Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  getCommunity,
  getMembership,
  isCommunityInviteManager,
  isPlatformAdmin,
  requireAuth
} from "./authorization.js";
import type {
  CallableAuth,
  CommunityInviteDoc,
  CommunityRole,
  MembershipDoc
} from "./types.js";

type SetCommunityMemberRoleInput = {
  communityId?: unknown;
  targetUid?: unknown;
  role?: unknown;
};

type CommunityIdInput = {
  communityId?: unknown;
};

export type AdminCommunityScope = {
  communityId: string;
  communityName: string;
  role: "leader" | "admin";
  communityStatus: "active" | "inactive" | "archived";
};

export type CommunityMembershipScope = {
  communityId: string;
  communityName: string;
  communityStatus: "active" | "inactive" | "archived";
  timezone: string;
  role: CommunityRole;
  membershipStatus: "active";
  joinedAt: string;
  memberCount?: number;
};

export type SafeCommunityInvite = {
  inviteId: string;
  communityId: string;
  status: CommunityInviteDoc["status"];
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  useCount: number;
  expiresAt?: string;
  maxUses?: number;
  lastUsedAt?: string;
  label?: string;
};

const allowedRoles: CommunityRole[] = ["member", "leader", "admin"];

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.trim().length > 128) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  return value.trim();
}

function requireRole(value: unknown): CommunityRole {
  if (typeof value !== "string" || !allowedRoles.includes(value as CommunityRole)) {
    throw new HttpsError("invalid-argument", "role is invalid.");
  }

  return value as CommunityRole;
}

export async function setCommunityMemberRoleCore(
  db: Firestore,
  authInput: CallableAuth,
  input: SetCommunityMemberRoleInput
): Promise<{ communityId: string; targetUid: string; role: CommunityRole }> {
  const auth = requireAuth(authInput);
  const communityId = requireString(input.communityId, "communityId");
  const targetUid = requireString(input.targetUid, "targetUid");
  const role = requireRole(input.role);
  const platformAdmin = isPlatformAdmin(auth);

  if (!platformAdmin && targetUid === auth.uid) {
    throw new HttpsError("permission-denied", "Community admins cannot change their own role.");
  }

  const communityRef = db.collection("communities").doc(communityId);
  const memberRef = communityRef.collection("members").doc(targetUid);
  const callerMemberRef = communityRef.collection("members").doc(auth.uid);

  await db.runTransaction(async (transaction) => {
    const [communitySnapshot, memberSnapshot, callerMemberSnapshot] = await Promise.all([
      transaction.get(communityRef),
      transaction.get(memberRef),
      platformAdmin ? Promise.resolve(null) : transaction.get(callerMemberRef)
    ]);

    if (!communitySnapshot.exists) {
      throw new HttpsError("not-found", "Community not found.");
    }

    const community = communitySnapshot.data();
    if (!platformAdmin) {
      const callerMembership = callerMemberSnapshot?.exists
        ? callerMemberSnapshot.data() as MembershipDoc
        : null;
      if (
        community?.status !== "active" ||
        callerMembership?.uid !== auth.uid ||
        callerMembership.status !== "active" ||
        callerMembership.role !== "admin"
      ) {
        throw new HttpsError("permission-denied", "Community admin permission is required.");
      }
    }

    if (!memberSnapshot.exists) {
      throw new HttpsError(platformAdmin ? "not-found" : "permission-denied", "Membership not found.");
    }

    const membership = memberSnapshot.data() as MembershipDoc;
    if (membership.uid !== targetUid) {
      throw new HttpsError("failed-precondition", "Membership UID is inconsistent.");
    }

    if (!platformAdmin) {
      if (role === "admin" || membership.role === "admin") {
        throw new HttpsError("permission-denied", "Community admin roles are managed by Platform Admin.");
      }
      if (membership.status !== "active") {
        throw new HttpsError("failed-precondition", "Only active members can have their role changed.");
      }
    }

    if (role !== "member" && membership.status !== "active") {
      throw new HttpsError("failed-precondition", "Only active members can be promoted.");
    }
    if (community?.primaryLeaderUid === targetUid && role === "member") {
      throw new HttpsError(
        "failed-precondition",
        "The primary leader must be reassigned before this role can be changed to member."
      );
    }

    transaction.update(memberRef, {
      role,
      updatedAt: Timestamp.now()
    });
  });

  return { communityId, targetUid, role };
}

export async function getMyAdminCommunitiesCore(
  db: Firestore,
  authInput: CallableAuth
): Promise<{ communities: AdminCommunityScope[] }> {
  const auth = requireAuth(authInput);
  const memberships = await db.collectionGroup("members").where("uid", "==", auth.uid).get();
  const eligible = memberships.docs.filter((snapshot) => {
    const membership = snapshot.data() as MembershipDoc;
    return membership.status === "active" && (membership.role === "leader" || membership.role === "admin");
  });

  const communities = await Promise.all(
    eligible.map(async (snapshot): Promise<AdminCommunityScope | null> => {
      const communityRef = snapshot.ref.parent.parent;
      if (!communityRef) return null;

      const communitySnapshot = await communityRef.get();
      if (!communitySnapshot.exists) return null;

      const membership = snapshot.data() as MembershipDoc;
      const community = communitySnapshot.data();
      if (
        !community ||
        typeof community.name !== "string" ||
        !["active", "inactive", "archived"].includes(community.status)
      ) {
        return null;
      }

      return {
        communityId: communityRef.id,
        communityName: community.name,
        role: membership.role as "leader" | "admin",
        communityStatus: community.status
      };
    })
  );

  return {
    communities: communities
      .filter((community): community is AdminCommunityScope => community !== null)
      .sort((left, right) => left.communityName.localeCompare(right.communityName))
  };
}

export async function getMyCommunitiesCore(
  db: Firestore,
  authInput: CallableAuth
): Promise<{ communities: CommunityMembershipScope[] }> {
  const auth = requireAuth(authInput);
  const memberships = await db.collectionGroup("members").where("uid", "==", auth.uid).get();
  const activeMemberships = memberships.docs.filter((snapshot) => {
    const membership = snapshot.data() as MembershipDoc;
    return membership.uid === auth.uid && membership.status === "active";
  });

  const communities = await Promise.all(
    activeMemberships.map(async (snapshot): Promise<CommunityMembershipScope | null> => {
      const communityRef = snapshot.ref.parent.parent;
      if (!communityRef) return null;

      const communitySnapshot = await communityRef.get();
      if (!communitySnapshot.exists) return null;

      const membership = snapshot.data() as MembershipDoc;
      const community = communitySnapshot.data();
      if (
        !community ||
        typeof community.name !== "string" ||
        typeof community.timezone !== "string" ||
        !["active", "inactive", "archived"].includes(community.status) ||
        !allowedRoles.includes(membership.role) ||
        !(membership.joinedAt instanceof Timestamp)
      ) {
        return null;
      }

      return {
        communityId: communityRef.id,
        communityName: community.name,
        communityStatus: community.status as CommunityMembershipScope["communityStatus"],
        timezone: community.timezone,
        role: membership.role,
        membershipStatus: "active",
        joinedAt: membership.joinedAt.toDate().toISOString(),
        ...(typeof community.memberCount === "number" && community.memberCount >= 0
          ? { memberCount: community.memberCount }
          : {})
      };
    })
  );

  return {
    communities: communities
      .filter((community): community is CommunityMembershipScope => community !== null)
      .sort((left, right) => {
        const joinedComparison = left.joinedAt.localeCompare(right.joinedAt);
        return joinedComparison !== 0
          ? joinedComparison
          : left.communityId.localeCompare(right.communityId);
      })
  };
}

export async function listManagedCommunityInvitesCore(
  db: Firestore,
  authInput: CallableAuth,
  input: CommunityIdInput
): Promise<{ invites: SafeCommunityInvite[] }> {
  const auth = requireAuth(authInput);
  const communityId = requireString(input.communityId, "communityId");
  await getCommunity(db, communityId);

  if (!isPlatformAdmin(auth)) {
    const membership = await getMembership(db, communityId, auth.uid);
    if (!isCommunityInviteManager(membership)) {
      throw new HttpsError("permission-denied", "Community management permission is required.");
    }
  }

  const snapshot = await db.collection("communityInvites").where("communityId", "==", communityId).get();
  const invites = snapshot.docs.map((item): SafeCommunityInvite => {
    const invite = item.data() as CommunityInviteDoc;
    return {
      inviteId: item.id,
      communityId: invite.communityId,
      status: invite.status,
      createdBy: invite.createdBy,
      createdAt: invite.createdAt.toDate().toISOString(),
      updatedAt: invite.updatedAt.toDate().toISOString(),
      useCount: invite.useCount,
      ...(invite.expiresAt ? { expiresAt: invite.expiresAt.toDate().toISOString() } : {}),
      ...(invite.maxUses ? { maxUses: invite.maxUses } : {}),
      ...(invite.lastUsedAt ? { lastUsedAt: invite.lastUsedAt.toDate().toISOString() } : {}),
      ...(invite.label ? { label: invite.label } : {})
    };
  });

  return {
    invites: invites.sort((left, right) => right.createdAt.localeCompare(left.createdAt))
  };
}

export const setCommunityMemberRole = onCall(async (request) => {
  return setCommunityMemberRoleCore(
    getFirestore(),
    request.auth,
    request.data as SetCommunityMemberRoleInput
  );
});

export const getMyAdminCommunities = onCall(async (request) => {
  return getMyAdminCommunitiesCore(getFirestore(), request.auth);
});

export const getMyCommunities = onCall({ invoker: "public" }, async (request) => {
  return getMyCommunitiesCore(getFirestore(), request.auth);
});

export const listManagedCommunityInvites = onCall(async (request) => {
  return listManagedCommunityInvitesCore(
    getFirestore(),
    request.auth,
    request.data as CommunityIdInput
  );
});
