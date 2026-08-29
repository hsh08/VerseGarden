import type { Timestamp } from "firebase/firestore";

export type CommunityStatus = "active" | "inactive" | "archived";
export type CommunityRole = "member" | "leader" | "admin";
export type MembershipStatus = "active" | "removed" | "banned" | "left";
export type CommunityInviteStatus = "active" | "revoked" | "expired";

export type CommunityAdminScope = {
  communityId: string;
  communityName: string;
  role: "leader" | "admin";
  communityStatus: CommunityStatus;
};

export type Community = {
  id: string;
  name: string;
  description?: string;
  status: CommunityStatus;
  timezone: string;
  primaryLeaderUid?: string;
  inviteEnabled?: boolean;
  memberCount?: number;
  createdBy: string;
  updatedBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
};

export type CommunityFormValues = {
  name: string;
  description: string;
  timezone: string;
  inviteEnabled: boolean;
};

export type CommunityMembership = {
  uid: string;
  role: CommunityRole;
  status: MembershipStatus;
  displayName?: string;
  invitedBy?: string;
  joinedAt: Timestamp;
  updatedAt: Timestamp;
};

export type CommunityInviteSummary = {
  id: string;
  communityId: string;
  status: CommunityInviteStatus;
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  useCount: number;
  expiresAt?: Timestamp;
  maxUses?: number;
  lastUsedAt?: Timestamp;
  label?: string;
};

export type GeneratedCommunityInvite = {
  inviteId: string;
  code: string;
  communityId: string;
  status: "active";
  expiresAt?: string;
  maxUses?: number;
  label?: string;
};
