import type { Timestamp } from "firebase-admin/firestore";

export type CallableAuth = {
  uid: string;
  token?: Record<string, unknown>;
} | null | undefined;

export type CommunityStatus = "active" | "inactive" | "archived";
export type CommunityRole = "member" | "leader" | "admin";
export type MembershipStatus = "active" | "removed" | "banned" | "left";
export type InviteStatus = "active" | "revoked" | "expired";

export type CommunityDoc = {
  name: string;
  status: CommunityStatus;
  timezone: string;
  primaryLeaderUid?: string;
  inviteEnabled?: boolean;
  memberCount?: number;
};

export type MembershipDoc = {
  uid: string;
  displayName?: string;
  role: CommunityRole;
  status: MembershipStatus;
  joinedAt: Timestamp;
  updatedAt: Timestamp;
};

export type CommunityInviteDoc = {
  communityId: string;
  codeHash: string;
  status: InviteStatus;
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  useCount: number;
  expiresAt?: Timestamp;
  maxUses?: number;
  lastUsedAt?: Timestamp;
  label?: string;
};

export type SafeCommunitySummary = {
  communityId: string;
  name: string;
  status: CommunityStatus;
  timezone: string;
  memberCount: number;
  membershipStatus: MembershipStatus;
  alreadyMember: boolean;
};
