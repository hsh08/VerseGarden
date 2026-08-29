"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { CommunityForm } from "@/components/CommunityForm";
import { CommunityInvitePanel } from "@/components/CommunityInvitePanel";
import { CommunityMembersTable } from "@/components/CommunityMembersTable";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { FormDialog } from "@/components/FormDialog";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { useAdminAuth } from "@/lib/auth";
import {
  getCommunity,
  listCommunityInvites,
  listCommunityMembers,
  updateCommunityMetadata,
  updateCommunityStatus
} from "@/lib/communities";
import { formatDateTime } from "@/lib/date";
import { memberDisplayName, shortUid } from "@/lib/memberIdentity";
import type {
  Community,
  CommunityFormValues,
  CommunityInviteSummary,
  CommunityMembership,
  CommunityStatus
} from "@/types/community";

type Tab = "overview" | "members" | "dailyQt" | "invitation" | "settings";
type LifecycleAction = { status: CommunityStatus; title: string; message: string } | null;

export default function CommunityDetailPage() {
  const params = useParams<{ communityId: string }>();
  const communityId = params.communityId;
  const { user } = useAdminAuth();
  const { withGlobalLoading } = useGlobalLoading();
  const [community, setCommunity] = useState<Community | null>(null);
  const [members, setMembers] = useState<CommunityMembership[]>([]);
  const [invites, setInvites] = useState<CommunityInviteSummary[]>([]);
  const [tab, setTab] = useState<Tab>("overview");
  const [isEditing, setIsEditing] = useState(false);
  const [values, setValues] = useState<CommunityFormValues | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [lifecycle, setLifecycle] = useState<LifecycleAction>(null);
  const [dialog, setDialog] = useState<{ title: string; message: string; tone?: "error" } | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const [nextCommunity, nextMembers, nextInvites] = await Promise.all([
        getCommunity(communityId),
        listCommunityMembers(communityId),
        listCommunityInvites(communityId)
      ]);
      setCommunity(nextCommunity);
      setMembers(nextMembers);
      setInvites(nextInvites);
      if (nextCommunity) setValues(formValues(nextCommunity));
    } catch (error) {
      setLoadError(friendlyErrorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, [communityId]);

  useEffect(() => {
    void load();
  }, [load]);

  const reloadInvites = useCallback(async () => {
    const nextInvites = await listCommunityInvites(communityId);
    setInvites(nextInvites);
    return nextInvites;
  }, [communityId]);

  const reloadMembers = useCallback(async () => {
    setMembers(await listCommunityMembers(communityId));
  }, [communityId]);

  async function handleSave() {
    if (!community || !values || !user) return;
    setIsSaving(true);
    try {
      await withGlobalLoading(async () => {
        await updateCommunityMetadata(community.id, values, user.uid);
        const updated = await getCommunity(community.id);
        setCommunity(updated);
        if (updated) setValues(formValues(updated));
        setIsEditing(false);
        setDialog({ title: "공동체 정보가 저장되었습니다", message: "변경한 운영 정보가 반영되었습니다." });
      }, "공동체 정보를 저장하는 중...");
    } catch (error) {
      setDialog({
        title: "공동체 정보를 저장할 수 없습니다",
        message: error instanceof Error ? error.message : "입력 내용을 확인해주세요.",
        tone: "error"
      });
    } finally {
      setIsSaving(false);
    }
  }

  async function handleLifecycleChange() {
    if (!community || !user || !lifecycle) return;
    const nextStatus = lifecycle.status;
    setLifecycle(null);
    setIsSaving(true);
    try {
      await withGlobalLoading(async () => {
        await updateCommunityStatus(community.id, nextStatus, user.uid);
        const updated = await getCommunity(community.id);
        setCommunity(updated);
        if (updated) setValues(formValues(updated));
        setDialog({ title: "공동체 상태가 변경되었습니다", message: `현재 상태: ${nextStatus}` });
      }, "공동체 상태를 변경하는 중...");
    } catch (error) {
      setDialog({
        title: "공동체 상태를 변경할 수 없습니다",
        message: friendlyErrorMessage(error),
        tone: "error"
      });
    } finally {
      setIsSaving(false);
    }
  }

  function cancelEdit() {
    if (community) setValues(formValues(community));
    setIsEditing(false);
  }

  if (isLoading) return <div className="page-card">공동체 정보를 불러오는 중입니다.</div>;
  if (loadError) return <div className="alert error">{loadError}</div>;
  if (!community || !values) {
    return (
      <div className="empty-state prominent-empty">
        <strong>공동체를 찾을 수 없습니다.</strong>
        <Link className="button secondary" href="/admin/communities">공동체 목록으로</Link>
      </div>
    );
  }
  const primaryLeader = members.find((member) => member.uid === community.primaryLeaderUid);

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">Communities</p>
          <div className="title-with-status">
            <h1>{community.name}</h1>
            <CommunityStatusBadge status={community.status} />
          </div>
          <p className="muted">{community.description || "공동체 설명이 없습니다."}</p>
        </div>
        <Link className="button secondary" href="/admin/communities">목록으로</Link>
      </div>

      <div className="detail-tabs" role="tablist" aria-label="공동체 상세 섹션">
        {(["overview", "members", "dailyQt", "invitation", "settings"] as Tab[]).map((item) => (
          <button
            key={item}
            type="button"
            role="tab"
            aria-selected={tab === item}
            className={`detail-tab ${tab === item ? "active" : ""}`}
            onClick={() => setTab(item)}
          >
            {tabLabel(item)}
          </button>
        ))}
      </div>

      {tab === "overview" ? (
        <section className="page-card page-stack compact-stack">
          <div className="section-heading compact-heading">
            <div>
              <h2>기본 정보</h2>
              <p className="muted">공동체의 공개 운영 정보를 관리합니다.</p>
            </div>
            {!isEditing ? (
              <button className="button secondary" type="button" onClick={() => setIsEditing(true)}>
                수정하기
              </button>
            ) : null}
          </div>

          {isEditing ? (
            <>
              <CommunityForm values={values} onChange={setValues} disabled={isSaving} />
              <div className="editor-actions">
                <button className="button secondary" type="button" disabled={isSaving} onClick={cancelEdit}>취소</button>
                <button className="button primary" type="button" disabled={isSaving} onClick={() => void handleSave()}>
                  {isSaving ? "저장 중..." : "저장"}
                </button>
              </div>
            </>
          ) : (
            <div className="metadata-grid">
              <Metadata label="상태" value={<CommunityStatusBadge status={community.status} />} />
              <Metadata label="시간대" value={community.timezone} />
              <Metadata label="멤버 수" value={community.memberCount ?? "—"} />
              <Metadata label="초대" value={community.inviteEnabled === false ? "비활성" : "활성"} />
              <Metadata
                label="Primary Leader"
                value={primaryLeader
                  ? `${memberDisplayName(primaryLeader)} (${shortUid(primaryLeader.uid)})`
                  : community.primaryLeaderUid ? shortUid(community.primaryLeaderUid) : "—"}
                mono
              />
              <Metadata label="생성일" value={formatDateTime(community.createdAt)} />
              <Metadata label="수정일" value={formatDateTime(community.updatedAt)} />
              <Metadata label="Community ID" value={community.id} mono />
            </div>
          )}
        </section>
      ) : null}

      {tab === "members" ? (
        <section className="page-card">
          <CommunityMembersTable
            members={members}
            communityId={community.id}
            primaryLeaderUid={community.primaryLeaderUid}
            roleManagement="platform"
            onMembersChanged={reloadMembers}
          />
        </section>
      ) : null}

      {tab === "dailyQt" ? (
        <section className="page-card page-stack compact-stack">
          <div>
            <p className="eyebrow">{community.name}</p>
            <h2>Community Daily QT</h2>
            <p className="muted">
              글로벌 QT와 분리된 이 공동체의 묵상 콘텐츠를 관리합니다.
            </p>
          </div>
          <div className="button-row">
            <Link className="button primary" href={`/admin/community/${community.id}/qt`}>
              Community QT 관리
            </Link>
          </div>
        </section>
      ) : null}

      {tab === "invitation" ? (
        <section className="page-card">
          <CommunityInvitePanel
            community={community}
            initialInvites={invites}
            reloadInvites={reloadInvites}
          />
        </section>
      ) : null}

      {tab === "settings" ? (
        <section className="page-card page-stack compact-stack">
          <div>
            <h2>운영 상태</h2>
            <p className="muted">기록을 보존한 채 공동체 운영 상태를 변경합니다.</p>
          </div>
          <div className="lifecycle-grid">
            {community.status === "active" ? (
              <LifecycleButton
                title="공동체 비활성화"
                description="신규 가입과 초대 생성을 제한합니다."
                label="비활성화"
                onClick={() => setLifecycle({
                  status: "inactive",
                  title: "이 공동체를 비활성화할까요?",
                  message: "새로운 가입과 일부 운영 기능이 제한될 수 있습니다."
                })}
              />
            ) : null}
            {community.status === "inactive" ? (
              <LifecycleButton
                title="공동체 활성화"
                description="정상 운영 상태로 되돌립니다. 초대 허용은 기본 정보에서 다시 켤 수 있습니다."
                label="활성화"
                primary
                onClick={() => setLifecycle({
                  status: "active",
                  title: "공동체를 다시 활성화할까요?",
                  message: "공동체 운영을 다시 시작합니다."
                })}
              />
            ) : null}
            {community.status !== "archived" ? (
              <LifecycleButton
                title="공동체 보관"
                description="기존 기록은 유지하고 새로운 가입과 운영을 중지합니다."
                label="보관하기"
                destructive
                onClick={() => setLifecycle({
                  status: "archived",
                  title: "이 공동체를 보관할까요?",
                  message: "기존 기록은 유지되지만 새로운 가입과 운영은 중지됩니다."
                })}
              />
            ) : (
              <LifecycleButton
                title="공동체 복원"
                description="비활성 상태로 복원한 뒤 관리자가 명시적으로 활성화할 수 있습니다."
                label="비활성 상태로 복원"
                onClick={() => setLifecycle({
                  status: "inactive",
                  title: "공동체를 복원할까요?",
                  message: "보관된 공동체를 비활성 상태로 복원합니다."
                })}
              />
            )}
          </div>
        </section>
      ) : null}

      <FormDialog
        open={Boolean(lifecycle)}
        title={lifecycle?.title ?? ""}
        message={lifecycle?.message ?? ""}
        onClose={() => setLifecycle(null)}
        actions={[
          { label: "취소", variant: "secondary", onClick: () => setLifecycle(null) },
          {
            label: lifecycle?.status === "archived" ? "보관하기" : "변경하기",
            variant: lifecycle?.status === "archived" ? "destructive" : "primary",
            disabled: isSaving,
            onClick: () => void handleLifecycleChange()
          }
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

function formValues(community: Community): CommunityFormValues {
  return {
    name: community.name,
    description: community.description ?? "",
    timezone: community.timezone,
    inviteEnabled: community.inviteEnabled !== false
  };
}

function tabLabel(tab: Tab) {
  return {
    overview: "Overview",
    members: "Members",
    dailyQt: "Daily QT",
    invitation: "Invitation",
    settings: "Settings"
  }[tab];
}

function Metadata({ label, value, mono = false }: { label: string; value: React.ReactNode; mono?: boolean }) {
  return (
    <div className="metadata-card">
      <span>{label}</span>
      <strong className={mono ? "metadata-value" : ""}>{value}</strong>
    </div>
  );
}

function LifecycleButton({
  title,
  description,
  label,
  onClick,
  primary = false,
  destructive = false
}: {
  title: string;
  description: string;
  label: string;
  onClick: () => void;
  primary?: boolean;
  destructive?: boolean;
}) {
  return (
    <div className="lifecycle-card">
      <div>
        <strong>{title}</strong>
        <p>{description}</p>
      </div>
      <button
        type="button"
        className={`button ${destructive ? "destructive" : primary ? "primary" : "secondary"}`}
        onClick={onClick}
      >
        {label}
      </button>
    </div>
  );
}
