import type {
  CommunityInviteStatus,
  CommunityStatus,
  MembershipStatus
} from "@/types/community";

type Status = CommunityStatus | MembershipStatus | CommunityInviteStatus;

const labels: Record<Status, string> = {
  active: "Active",
  inactive: "Inactive",
  archived: "Archived",
  removed: "Removed",
  banned: "Banned",
  left: "Left",
  revoked: "Revoked",
  expired: "Expired"
};

export function CommunityStatusBadge({ status }: { status: Status }) {
  return <span className={`community-status-badge ${status}`}>{labels[status]}</span>;
}
