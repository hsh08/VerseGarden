export type CommunityRole = "member" | "leader" | "admin";
export type CommunityStatus = "active" | "inactive" | "archived";
export type MembershipStatus = "active" | "removed" | "banned" | "left";

export type CommunityMembership = {
  communityId: string;
  communityName: string;
  communityStatus: CommunityStatus;
  timezone: string;
  role: CommunityRole;
  membershipStatus: MembershipStatus;
  joinedAt: Date;
  memberCount?: number;
};

export type CommunityJoinResult = {
  communityId: string;
  communityName: string;
  alreadyMember: boolean;
};

export type CommunitySubmissionRequest = {
  communityId: string;
  dateKey: string;
  contentId: string;
  contentVersion: number;
  reflectionAnswer: string;
  applicationText: string;
};

export type PendingCommunitySubmission = Pick<CommunitySubmissionRequest, "communityId" | "dateKey" | "contentId" | "contentVersion"> & {
  recordId: string;
};

export function communityRoleLabel(role: CommunityRole): string {
  return role === "admin" ? "공동체 관리자" : role === "leader" ? "리더" : "멤버";
}

export function isOperationalMembership(value: CommunityMembership): boolean {
  return value.membershipStatus === "active" && value.communityStatus === "active";
}

export function parseISO8601(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function parseCommunityMembership(value: unknown): CommunityMembership | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  const role = item.role;
  const communityStatus = item.communityStatus;
  const membershipStatus = item.membershipStatus;
  const joinedAt = parseISO8601(item.joinedAt);
  if (
    typeof item.communityId !== "string" || !item.communityId ||
    typeof item.communityName !== "string" || !item.communityName ||
    typeof item.timezone !== "string" || !item.timezone ||
    (role !== "member" && role !== "leader" && role !== "admin") ||
    (communityStatus !== "active" && communityStatus !== "inactive" && communityStatus !== "archived") ||
    (membershipStatus !== "active" && membershipStatus !== "removed" && membershipStatus !== "banned" && membershipStatus !== "left") ||
    !joinedAt
  ) return null;
  return {
    communityId: item.communityId,
    communityName: item.communityName,
    communityStatus,
    timezone: item.timezone,
    role,
    membershipStatus,
    joinedAt,
    ...(typeof item.memberCount === "number" && Number.isFinite(item.memberCount) && item.memberCount >= 0 ? { memberCount: item.memberCount } : {}),
  };
}

export function selectCommunity(memberships: readonly CommunityMembership[], selectedId: string | null): CommunityMembership | null {
  const active = memberships.filter(isOperationalMembership);
  return active.find((item) => item.communityId === selectedId) ?? active[0] ?? null;
}

export function makeCommunitySubmissionRequest(record: {
  id: string; completedAt: Date | null; contentSource?: string; communityId?: string; contentDateKey?: string; dateKey: string; contentId?: string; contentVersion?: number; reflectionAnswer: string; applicationText: string;
}): CommunitySubmissionRequest | null {
  const communityId = record.communityId?.trim();
  const dateKey = (record.contentDateKey ?? record.dateKey).trim();
  const contentId = record.contentId?.trim();
  if (!record.completedAt || record.contentSource !== "community" || !communityId || !contentId || contentId !== dateKey || !record.contentVersion || record.contentVersion < 1) return null;
  return { communityId, dateKey, contentId, contentVersion: record.contentVersion, reflectionAnswer: record.reflectionAnswer, applicationText: record.applicationText };
}

export function pendingSubmissionFor(record: Parameters<typeof makeCommunitySubmissionRequest>[0]): PendingCommunitySubmission | null {
  const request = makeCommunitySubmissionRequest(record);
  return request ? { recordId: record.id, communityId: request.communityId, dateKey: request.dateKey, contentId: request.contentId, contentVersion: request.contentVersion } : null;
}

export function isRetryableCommunityError(error: unknown): boolean {
  const code = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
  return !["permission-denied", "invalid-argument", "not-found", "failed-precondition", "out-of-range", "unimplemented", "data-loss"].some((item) => code.includes(item));
}
