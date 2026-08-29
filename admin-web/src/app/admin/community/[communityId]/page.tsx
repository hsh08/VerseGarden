"use client";

import Link from "next/link";
import { useParams, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { CommunityInvitePanel } from "@/components/CommunityInvitePanel";
import { CommunityMembersTable } from "@/components/CommunityMembersTable";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { useAdminAuth } from "@/lib/auth";
import { getCommunity, listCommunityMembers } from "@/lib/communities";
import { listManagedCommunityInvites } from "@/lib/communityInvites";
import { formatDateTime } from "@/lib/date";
import { shortUid } from "@/lib/memberIdentity";
import type { Community, CommunityInviteSummary, CommunityMembership } from "@/types/community";

type Tab = "overview" | "members" | "invitation";

export default function ScopedCommunityPage() {
  const params = useParams<{ communityId: string }>();
  const searchParams = useSearchParams();
  const communityId = params.communityId;
  const { user, communityScopes } = useAdminAuth();
  const scope = communityScopes.find((item) => item.communityId === communityId);
  const canManageCommunity = scope?.role === "admin";
  const requestedTab = searchParams.get("tab");
  const tab: Tab = requestedTab === "members"
    ? "members"
    : requestedTab === "invitation" && canManageCommunity ? "invitation" : "overview";
  const [community, setCommunity] = useState<Community | null>(null);
  const [members, setMembers] = useState<CommunityMembership[]>([]);
  const [invites, setInvites] = useState<CommunityInviteSummary[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [nextCommunity, nextMembers, nextInvites] = await Promise.all([
        getCommunity(communityId),
        listCommunityMembers(communityId),
        canManageCommunity ? listManagedCommunityInvites(communityId) : Promise.resolve([])
      ]);
      setCommunity(nextCommunity);
      setMembers(nextMembers);
      setInvites(nextInvites);
    } catch (loadError) {
      setError(friendlyErrorMessage(loadError));
    } finally {
      setIsLoading(false);
    }
  }, [canManageCommunity, communityId]);

  useEffect(() => {
    void load();
  }, [load]);

  const reloadInvites = useCallback(async () => {
    if (!canManageCommunity) return [];
    const nextInvites = await listManagedCommunityInvites(communityId);
    setInvites(nextInvites);
    return nextInvites;
  }, [canManageCommunity, communityId]);

  const reloadMembers = useCallback(async () => {
    setMembers(await listCommunityMembers(communityId));
  }, [communityId]);

  if (isLoading) return <div className="page-card">공동체 정보를 불러오는 중입니다.</div>;
  if (error) return <div className="alert error">{error}</div>;
  if (!community) return <div className="empty-state">공동체를 찾을 수 없습니다.</div>;

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">Community</p>
          <div className="title-with-status"><h1>{community.name}</h1><CommunityStatusBadge status={community.status} /></div>
          <p className="muted">{community.description || "공동체 운영 정보를 확인합니다."}</p>
        </div>
        <Link className="button secondary" href="/admin">Dashboard</Link>
      </div>

      {community.status !== "active" ? (
        <div className="status-note">
          <p>현재 공동체는 {community.status} 상태입니다. 기록 조회는 가능하지만 새 초대 생성과 재생성은 제한됩니다.</p>
        </div>
      ) : null}

      <div className="detail-tabs" role="tablist" aria-label="공동체 관리 섹션">
        <TabLink communityId={communityId} tab="overview" current={tab} label="Overview" />
        <TabLink communityId={communityId} tab="members" current={tab} label="Members" />
        {canManageCommunity ? (
          <TabLink communityId={communityId} tab="invitation" current={tab} label="Invitation" />
        ) : null}
      </div>

      {tab === "overview" ? (
        <section className="page-card page-stack compact-stack">
          <div><h2>공동체 정보</h2><p className="muted">운영 메타데이터는 Platform Admin이 관리합니다.</p></div>
          <div className="metadata-grid">
            <Metadata label="상태" value={<CommunityStatusBadge status={community.status} />} />
            <Metadata label="시간대" value={community.timezone} />
            <Metadata label="멤버 수" value={community.memberCount ?? "—"} />
            <Metadata label="초대" value={community.inviteEnabled === false ? "비활성" : "활성"} />
            <Metadata
              label="Primary Leader"
              value={community.primaryLeaderUid ? shortUid(community.primaryLeaderUid) : "—"}
              mono
            />
            <Metadata label="생성일" value={formatDateTime(community.createdAt)} />
            <Metadata label="수정일" value={formatDateTime(community.updatedAt)} />
            <Metadata label="Community ID" value={community.id} mono />
          </div>
        </section>
      ) : null}

      {tab === "members" ? (
        <section className="page-card">
          <CommunityMembersTable
            members={members}
            communityId={communityId}
            currentUserUid={user?.uid}
            roleManagement={canManageCommunity ? "community" : "readOnly"}
            onMembersChanged={reloadMembers}
          />
        </section>
      ) : null}

      {tab === "invitation" && canManageCommunity ? (
        <section className="page-card">
          <CommunityInvitePanel community={community} initialInvites={invites} reloadInvites={reloadInvites} />
        </section>
      ) : null}
    </div>
  );
}

function TabLink({ communityId, tab, current, label }: { communityId: string; tab: Tab; current: Tab; label: string }) {
  const href = tab === "overview" ? `/admin/community/${communityId}` : `/admin/community/${communityId}?tab=${tab}`;
  return <Link role="tab" aria-selected={current === tab} className={`detail-tab ${current === tab ? "active" : ""}`} href={href}>{label}</Link>;
}

function Metadata({ label, value, mono = false }: { label: string; value: React.ReactNode; mono?: boolean }) {
  return <div className="metadata-card"><span>{label}</span><strong className={mono ? "metadata-value" : ""}>{value}</strong></div>;
}
