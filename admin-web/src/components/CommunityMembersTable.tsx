"use client";

import { useMemo, useState } from "react";
import { FormDialog } from "@/components/FormDialog";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { setCommunityMemberRole } from "@/lib/adminScope";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import { formatDateTime } from "@/lib/date";
import { memberDisplayName, shortUid } from "@/lib/memberIdentity";
import type {
  CommunityMembership,
  CommunityRole,
  MembershipStatus
} from "@/types/community";

const filters: Array<MembershipStatus | "all"> = [
  "all",
  "active",
  "removed",
  "banned",
  "left"
];

type Props = {
  members: CommunityMembership[];
  communityId?: string;
  primaryLeaderUid?: string;
  currentUserUid?: string;
  roleManagement?: "platform" | "community" | "readOnly";
  onMembersChanged?: () => Promise<void>;
};

type PendingRole = { member: CommunityMembership; role: CommunityRole } | null;

export function CommunityMembersTable({
  members,
  communityId,
  primaryLeaderUid,
  currentUserUid,
  roleManagement = "readOnly",
  onMembersChanged
}: Props) {
  const { withGlobalLoading } = useGlobalLoading();
  const [filter, setFilter] = useState<MembershipStatus | "all">("all");
  const [pendingRole, setPendingRole] = useState<PendingRole>(null);
  const [isMutating, setIsMutating] = useState(false);
  const [dialog, setDialog] = useState<{ title: string; message: string; tone?: "error" } | null>(null);
  const filteredMembers = useMemo(
    () => (filter === "all" ? members : members.filter((member) => member.status === filter)),
    [filter, members]
  );
  const canManageRoles = roleManagement !== "readOnly";

  async function confirmRoleChange() {
    if (!pendingRole || !communityId) return;
    const nextRole = pendingRole.role;
    const targetUid = pendingRole.member.uid;
    setPendingRole(null);
    setIsMutating(true);
    try {
      await withGlobalLoading(async () => {
        await setCommunityMemberRole(communityId, targetUid, nextRole);
        await onMembersChanged?.();
      }, "권한을 변경하는 중...");
      setDialog({
        title: "멤버 역할이 변경되었습니다",
        message: `${memberDisplayName(pendingRole.member)}님의 역할을 ${roleLabel(nextRole)}(으)로 변경했습니다.`
      });
    } catch (error) {
      setDialog({
        title: "역할을 변경할 수 없습니다",
        message: error instanceof Error ? error.message : "역할 변경 요청을 처리하지 못했습니다.",
        tone: "error"
      });
    } finally {
      setIsMutating(false);
    }
  }

  return (
    <div className="page-stack compact-stack">
      <div className="filter-row">
        {filters.map((item) => (
          <button
            key={item}
            type="button"
            className={`filter-button ${filter === item ? "active" : ""}`}
            onClick={() => setFilter(item)}
          >
            {item === "all" ? "All" : item}
          </button>
        ))}
      </div>

      {!filteredMembers.length ? (
        <div className="empty-state">아직 가입한 멤버가 없습니다.</div>
      ) : (
        <div className="table-card flat-card">
          <table>
            <thead>
              <tr>
                <th>Member</th>
                <th>Role</th>
                <th>Status</th>
                <th>Joined At</th>
                <th className="table-actions-column">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredMembers.map((member) => (
                <tr key={member.uid}>
                  <td>
                    <strong>{memberDisplayName(member)}</strong>
                    <span className="table-subtitle metadata-value" title={member.uid}>
                      UID: {shortUid(member.uid)}
                    </span>
                  </td>
                  <td><span className="role-label">{roleLabel(member.role)}</span></td>
                  <td><CommunityStatusBadge status={member.status} /></td>
                  <td>{formatDateTime(member.joinedAt)}</td>
                  <td className="table-actions-column">
                    {canEditMember(member, roleManagement, currentUserUid) && communityId ? (
                      <select
                        className="role-select"
                        aria-label={`${memberDisplayName(member)} 역할 변경`}
                        value={member.role}
                        disabled={isMutating}
                        onChange={(event) => setPendingRole({
                          member,
                          role: event.target.value as CommunityRole
                        })}
                      >
                        {roleOptions(roleManagement).map((role) => (
                          <option
                            key={role}
                            value={role}
                            disabled={
                              (role === "member" && member.uid === primaryLeaderUid) ||
                              (role !== "member" && member.status !== "active")
                            }
                          >
                            {roleLabel(role)}
                          </option>
                        ))}
                      </select>
                    ) : <span className="muted small">읽기 전용</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="muted small">
        {canManageRoles
          ? roleManagement === "platform"
            ? "Platform Admin은 Member, Leader, Admin 역할을 관리할 수 있습니다."
            : "공동체 관리자는 활성 Member와 Leader 역할만 변경할 수 있습니다."
          : "멤버 역할과 상태는 읽기 전용 운영 메타데이터입니다."}
      </p>

      <FormDialog
        open={Boolean(pendingRole)}
        title="멤버 역할을 변경할까요?"
        message={pendingRole
          ? `${memberDisplayName(pendingRole.member)}님의 역할을 ${roleLabel(pendingRole.role)}(으)로 변경합니다.`
          : ""}
        onClose={() => setPendingRole(null)}
        actions={[
          { label: "취소", variant: "secondary", onClick: () => setPendingRole(null) },
          { label: "변경하기", variant: "primary", disabled: isMutating, onClick: () => void confirmRoleChange() }
        ]}
      />

      <FormDialog
        open={Boolean(dialog)}
        title={dialog?.title ?? ""}
        message={dialog?.message ?? ""}
        tone={dialog?.tone ?? "default"}
        onClose={() => setDialog(null)}
      />
    </div>
  );
}

function roleLabel(role: CommunityRole): string {
  return { member: "Member", leader: "Leader", admin: "Admin" }[role];
}

function roleOptions(mode: NonNullable<Props["roleManagement"]>): CommunityRole[] {
  return mode === "platform" ? ["member", "leader", "admin"] : ["member", "leader"];
}

function canEditMember(
  member: CommunityMembership,
  mode: NonNullable<Props["roleManagement"]>,
  currentUserUid?: string
): boolean {
  if (mode === "platform") return true;
  if (mode !== "community") return false;
  return member.status === "active" && member.role !== "admin" && member.uid !== currentUserUid;
}
