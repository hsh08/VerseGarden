import type { CommunityMembership, CommunityRole } from "@/types/community";

export function memberDisplayName(member: Pick<CommunityMembership, "displayName">): string {
  return member.displayName?.trim() || "사용자";
}

export function shortUid(uid: string): string {
  if (uid.length <= 14) return uid;
  return `${uid.slice(0, 6)}...${uid.slice(-4)}`;
}

export function communityRoleLabel(role: CommunityRole): string {
  return {
    member: "멤버",
    leader: "리더",
    admin: "공동체 관리자"
  }[role];
}
