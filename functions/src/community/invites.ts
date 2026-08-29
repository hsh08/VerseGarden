import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  formatInviteCode,
  generateInviteCode,
  hashInviteCode,
  normalizeInviteCode
} from "./inviteCodes.js";
import {
  requireAuth,
  requireInviteManagementPermission,
  requireInvitePermissionForExistingInvite
} from "./authorization.js";
import type { CallableAuth, CommunityDoc, CommunityInviteDoc, MembershipDoc, SafeCommunitySummary } from "./types.js";

const MAX_INVITE_CREATE_ATTEMPTS = 5;
const MAX_MEMBERSHIP_DISPLAY_NAME_LENGTH = 80;

type CreateCommunityInviteInput = {
  communityId?: unknown;
  expiresAt?: unknown;
  maxUses?: unknown;
  label?: unknown;
};

type InviteCodeInput = {
  code?: unknown;
};

type InviteIdentifierInput = {
  code?: unknown;
  inviteId?: unknown;
};

export type CreateCommunityInviteResult = {
  inviteId: string;
  code: string;
  communityId: string;
  status: "active";
  expiresAt?: string;
  maxUses?: number;
  label?: string;
};

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }

  return value.trim();
}

function optionalTimestamp(value: unknown, fieldName: string): Timestamp | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (typeof value !== "string" && typeof value !== "number") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a date value.`);
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a valid date value.`);
  }

  return Timestamp.fromDate(date);
}

function optionalPositiveInteger(value: unknown, fieldName: string): number | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a positive integer.`);
  }

  return value;
}

function optionalLabel(value: unknown): string | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "label must be a string.");
  }

  const trimmed = value.trim();
  if (trimmed.length > 80) {
    throw new HttpsError("invalid-argument", "label must be 80 characters or fewer.");
  }

  return trimmed.length > 0 ? trimmed : undefined;
}

function inviteIdFromIdentifier(input: InviteIdentifierInput): string {
  if (typeof input.inviteId === "string" && /^[a-f0-9]{64}$/i.test(input.inviteId)) {
    return input.inviteId.toLowerCase();
  }

  const normalizedCode = normalizeInviteCode(input.code);
  return hashInviteCode(normalizedCode);
}

function safeCommunitySummary(
  communityId: string,
  community: CommunityDoc,
  membershipStatus: SafeCommunitySummary["membershipStatus"],
  alreadyMember: boolean,
  memberCountDelta = 0
): SafeCommunitySummary {
  return {
    communityId,
    name: community.name,
    status: community.status,
    timezone: community.timezone,
    memberCount: Math.max(0, (community.memberCount ?? 0) + memberCountDelta),
    membershipStatus,
    alreadyMember
  };
}

function normalizedDisplayName(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  if (!normalized) return undefined;
  return normalized.slice(0, MAX_MEMBERSHIP_DISPLAY_NAME_LENGTH);
}

async function resolveMembershipDisplayName(
  db: Firestore,
  auth: NonNullable<CallableAuth>
): Promise<string | undefined> {
  const profileSnapshot = await db.collection("users").doc(auth.uid).get();
  const profile = profileSnapshot.data();

  return normalizedDisplayName(profile?.nickname)
    ?? normalizedDisplayName(profile?.displayName)
    ?? normalizedDisplayName(auth.token?.name);
}

function assertInviteCanBeRedeemedByNewOrRejoiningMember(invite: CommunityInviteDoc, now: Timestamp) {
  if (invite.maxUses !== undefined && invite.useCount >= invite.maxUses) {
    throw new HttpsError("resource-exhausted", "Invite has reached its use limit.");
  }

  if (invite.expiresAt !== undefined && invite.expiresAt.toMillis() <= now.toMillis()) {
    throw new HttpsError("failed-precondition", "Invite has expired.");
  }
}

function assertInviteIsActive(invite: CommunityInviteDoc) {
  if (invite.status === "revoked") {
    throw new HttpsError("failed-precondition", "Invite has been revoked.");
  }

  if (invite.status === "expired") {
    throw new HttpsError("failed-precondition", "Invite has expired.");
  }

  if (invite.status !== "active") {
    throw new HttpsError("failed-precondition", "Invite is not active.");
  }
}

export async function createCommunityInviteCore(
  db: Firestore,
  authInput: CallableAuth,
  input: CreateCommunityInviteInput
): Promise<CreateCommunityInviteResult> {
  const communityId = requireString(input.communityId, "communityId");
  const expiresAt = optionalTimestamp(input.expiresAt, "expiresAt");
  const maxUses = optionalPositiveInteger(input.maxUses, "maxUses");
  const label = optionalLabel(input.label);
  const { auth } = await requireInviteManagementPermission(db, authInput, communityId);

  for (let attempt = 0; attempt < MAX_INVITE_CREATE_ATTEMPTS; attempt += 1) {
    const code = generateInviteCode();
    const normalizedCode = normalizeInviteCode(code);
    const inviteId = hashInviteCode(normalizedCode);
    const now = Timestamp.now();
    const payload: CommunityInviteDoc = {
      communityId,
      codeHash: inviteId,
      status: "active",
      createdBy: auth.uid,
      createdAt: now,
      updatedAt: now,
      useCount: 0,
      ...(expiresAt ? { expiresAt } : {}),
      ...(maxUses ? { maxUses } : {}),
      ...(label ? { label } : {})
    };

    try {
      await db.collection("communityInvites").doc(inviteId).create(payload);
      return {
        inviteId,
        code: formatInviteCode(normalizedCode),
        communityId,
        status: "active",
        ...(expiresAt ? { expiresAt: expiresAt.toDate().toISOString() } : {}),
        ...(maxUses ? { maxUses } : {}),
        ...(label ? { label } : {})
      };
    } catch (error) {
      const maybeCode = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
      if (maybeCode !== "6" && maybeCode !== "already-exists") {
        throw error;
      }
    }
  }

  throw new HttpsError("internal", "Unable to generate a unique invite code.");
}

export async function revokeCommunityInviteCore(
  db: Firestore,
  authInput: CallableAuth,
  input: InviteIdentifierInput
): Promise<{ inviteId: string; status: "revoked" }> {
  const inviteId = inviteIdFromIdentifier(input);
  const inviteRef = db.collection("communityInvites").doc(inviteId);
  const inviteSnapshot = await inviteRef.get();
  if (!inviteSnapshot.exists) {
    throw new HttpsError("not-found", "Invite not found.");
  }

  const invite = inviteSnapshot.data() as CommunityInviteDoc;
  await requireInvitePermissionForExistingInvite(db, authInput, invite);

  await inviteRef.update({
    status: "revoked",
    updatedAt: Timestamp.now()
  });

  return { inviteId, status: "revoked" };
}

export async function regenerateCommunityInviteCore(
  db: Firestore,
  authInput: CallableAuth,
  input: InviteIdentifierInput
): Promise<CreateCommunityInviteResult> {
  const inviteId = inviteIdFromIdentifier(input);
  const inviteRef = db.collection("communityInvites").doc(inviteId);
  const inviteSnapshot = await inviteRef.get();
  if (!inviteSnapshot.exists) {
    throw new HttpsError("not-found", "Invite not found.");
  }

  const invite = inviteSnapshot.data() as CommunityInviteDoc;
  await requireInvitePermissionForExistingInvite(db, authInput, invite);
  const { auth } = await requireInviteManagementPermission(db, authInput, invite.communityId);

  for (let attempt = 0; attempt < MAX_INVITE_CREATE_ATTEMPTS; attempt += 1) {
    const code = generateInviteCode();
    const normalizedCode = normalizeInviteCode(code);
    const newInviteId = hashInviteCode(normalizedCode);
    const newInviteRef = db.collection("communityInvites").doc(newInviteId);
    const now = Timestamp.now();
    const payload: CommunityInviteDoc = {
      communityId: invite.communityId,
      codeHash: newInviteId,
      status: "active",
      createdBy: auth.uid,
      createdAt: now,
      updatedAt: now,
      useCount: 0,
      ...(invite.expiresAt ? { expiresAt: invite.expiresAt } : {}),
      ...(invite.maxUses ? { maxUses: invite.maxUses } : {}),
      ...(invite.label ? { label: invite.label } : {})
    };

    try {
      await db.runTransaction(async (transaction) => {
        const currentInviteSnapshot = await transaction.get(inviteRef);
        if (!currentInviteSnapshot.exists) {
          throw new HttpsError("not-found", "Invite not found.");
        }

        transaction.create(newInviteRef, payload);
        transaction.update(inviteRef, {
          status: "revoked",
          updatedAt: now
        });
      });

      return {
        inviteId: newInviteId,
        code: formatInviteCode(normalizedCode),
        communityId: invite.communityId,
        status: "active",
        ...(invite.expiresAt ? { expiresAt: invite.expiresAt.toDate().toISOString() } : {}),
        ...(invite.maxUses ? { maxUses: invite.maxUses } : {}),
        ...(invite.label ? { label: invite.label } : {})
      };
    } catch (error) {
      const maybeCode = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
      if (maybeCode !== "6" && maybeCode !== "already-exists") {
        throw error;
      }
    }
  }

  throw new HttpsError("internal", "Unable to generate a unique invite code.");
}

export async function redeemCommunityInviteCore(
  db: Firestore,
  authInput: CallableAuth,
  input: InviteCodeInput
): Promise<SafeCommunitySummary> {
  const auth = requireAuth(authInput);
  const normalizedCode = normalizeInviteCode(input.code);
  const inviteId = hashInviteCode(normalizedCode);
  const displayName = await resolveMembershipDisplayName(db, auth);

  return db.runTransaction(async (transaction) => {
    const inviteRef = db.collection("communityInvites").doc(inviteId);
    const inviteSnapshot = await transaction.get(inviteRef);
    if (!inviteSnapshot.exists) {
      throw new HttpsError("not-found", "Invalid invite code.");
    }

    const invite = inviteSnapshot.data() as CommunityInviteDoc;
    assertInviteIsActive(invite);

    const communityRef = db.collection("communities").doc(invite.communityId);
    const communitySnapshot = await transaction.get(communityRef);
    if (!communitySnapshot.exists) {
      throw new HttpsError("failed-precondition", "Community is not available.");
    }

    const community = communitySnapshot.data() as CommunityDoc;
    if (community.status !== "active") {
      throw new HttpsError("failed-precondition", "Community is not active.");
    }
    if (community.inviteEnabled === false) {
      throw new HttpsError("failed-precondition", "Community invites are disabled.");
    }

    if (invite.expiresAt !== undefined && invite.expiresAt.toMillis() <= Timestamp.now().toMillis()) {
      transaction.update(inviteRef, {
        status: "expired",
        updatedAt: Timestamp.now()
      });
      throw new HttpsError("failed-precondition", "Invite has expired.");
    }

    const memberRef = communityRef.collection("members").doc(auth.uid);
    const membershipSnapshot = await transaction.get(memberRef);
    const existingMembership = membershipSnapshot.exists ? membershipSnapshot.data() as MembershipDoc : null;
    const now = Timestamp.now();

    if (existingMembership?.status === "active") {
      if (!existingMembership.displayName && displayName) {
        transaction.update(memberRef, {
          displayName,
          updatedAt: now
        });
      }
      return safeCommunitySummary(invite.communityId, community, "active", true);
    }

    if (existingMembership?.status === "removed" || existingMembership?.status === "banned") {
      throw new HttpsError("permission-denied", "This account cannot join the community with this invite.");
    }

    assertInviteCanBeRedeemedByNewOrRejoiningMember(invite, now);

    if (existingMembership?.status === "left") {
      transaction.update(memberRef, {
        status: "active",
        role: "member",
        ...(displayName ? { displayName } : {}),
        updatedAt: now
      });
    } else {
      transaction.create(memberRef, {
        uid: auth.uid,
        ...(displayName ? { displayName } : {}),
        role: "member",
        status: "active",
        joinedAt: now,
        updatedAt: now
      });
    }

    transaction.update(inviteRef, {
      useCount: FieldValue.increment(1),
      lastUsedAt: now,
      updatedAt: now
    });
    transaction.update(communityRef, {
      memberCount: FieldValue.increment(1),
      updatedAt: now
    });

    return safeCommunitySummary(invite.communityId, community, "active", false, 1);
  });
}

export const createCommunityInvite = onCall({ invoker: "public" }, async (request) => {
  return createCommunityInviteCore(getFirestore(), request.auth, request.data as CreateCommunityInviteInput);
});

export const revokeCommunityInvite = onCall(async (request) => {
  return revokeCommunityInviteCore(getFirestore(), request.auth, request.data as InviteIdentifierInput);
});

export const regenerateCommunityInvite = onCall(async (request) => {
  return regenerateCommunityInviteCore(getFirestore(), request.auth, request.data as InviteIdentifierInput);
});

export const redeemCommunityInvite = onCall(async (request) => {
  return redeemCommunityInviteCore(getFirestore(), request.auth, request.data as InviteCodeInput);
});
