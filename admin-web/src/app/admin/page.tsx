"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { StatusBadge } from "@/components/StatusBadge";
import { useAdminAuth } from "@/lib/auth";
import { getCommunity, listCommunities } from "@/lib/communities";
import { listManagedCommunityInvites } from "@/lib/communityInvites";
import { formatDateTime, formatDisplayDate } from "@/lib/date";
import { shortUid } from "@/lib/memberIdentity";
import { getDashboardSummary } from "@/lib/dailyQuietTimes";
import type { Community, CommunityInviteSummary } from "@/types/community";
import type { DailyQuietTime } from "@/types/dailyQuietTime";

type Summary = {
  today: string;
  todayContent: DailyQuietTime | null;
  weeklyCount: number;
  weeklyPublishedCount: number;
};

type CommunitySummary = { total: number; active: number; totalMembers: number };

export default function AdminDashboardPage() {
  const { state, selectedCommunityId, communityScopes } = useAdminAuth();

  if (state === "communityAdmin" && selectedCommunityId) {
    const scope = communityScopes.find((item) => item.communityId === selectedCommunityId);
    return <CommunityAdminDashboard communityId={selectedCommunityId} role={scope?.role ?? "leader"} />;
  }

  return <PlatformAdminDashboard />;
}

function PlatformAdminDashboard() {
  const [summary, setSummary] = useState<Summary | null>(null);
  const [communitySummary, setCommunitySummary] = useState<CommunitySummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([getDashboardSummary(), listCommunities()])
      .then(([nextSummary, communities]) => {
        setSummary(nextSummary);
        setCommunitySummary({
          total: communities.length,
          active: communities.filter((community) => community.status === "active").length,
          totalMembers: communities.reduce((sum, community) => sum + (community.memberCount ?? 0), 0)
        });
      })
      .catch((dashboardError) => setError(friendlyErrorMessage(dashboardError)));
  }, []);

  if (error) return <div className="alert error">{error}</div>;
  if (!summary) return <div className="page-card">Dashboard를 불러오는 중입니다.</div>;

  return (
    <div className="page-stack">
      <div className="page-header">
        <div><p className="eyebrow">{formatDisplayDate(summary.today)}</p><h1>Dashboard</h1></div>
        <Link className="button primary" href="/admin/qt/new">새 QT 작성</Link>
      </div>

      <section className="card-grid">
        <div className="metric-card">
          <span>오늘 QT</span>
          <strong>{summary.todayContent ? summary.todayContent.title : "없음"}</strong>
          {summary.todayContent ? (
            <><p>{summary.todayContent.reference}</p><StatusBadge status={summary.todayContent.status} /></>
          ) : <p>오늘 날짜의 QT가 없습니다.</p>}
        </div>
        <Metric label="이번 주 작성 QT" value={summary.weeklyCount} description="dailyQuietTimes 기준" />
        <Metric label="이번 주 Published" value={summary.weeklyPublishedCount} description="사용자에게 공개된 QT" />
      </section>

      <div className="section-heading compact-heading">
        <div><p className="eyebrow">Platform</p><h2>Community 운영</h2></div>
        <Link className="button secondary" href="/admin/communities">공동체 관리</Link>
      </div>
      <section className="card-grid">
        <Metric label="전체 공동체" value={communitySummary?.total ?? 0} description="등록된 Community 문서" />
        <Metric label="활성 공동체" value={communitySummary?.active ?? 0} description="현재 운영 중인 공동체" />
        <Metric label="전체 멤버" value={communitySummary?.totalMembers ?? 0} description="신뢰된 memberCount 합계" />
      </section>
    </div>
  );
}

function CommunityAdminDashboard({ communityId, role }: { communityId: string; role: "leader" | "admin" }) {
  const [community, setCommunity] = useState<Community | null>(null);
  const [invites, setInvites] = useState<CommunityInviteSummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setCommunity(null);
    setError(null);
    Promise.all([
      getCommunity(communityId),
      role === "admin" ? listManagedCommunityInvites(communityId) : Promise.resolve([])
    ])
      .then(([nextCommunity, nextInvites]) => {
        setCommunity(nextCommunity);
        setInvites(nextInvites);
      })
      .catch((loadError) => setError(friendlyErrorMessage(loadError)));
  }, [communityId]);

  if (error) return <div className="alert error">{error}</div>;
  if (!community) return <div className="page-card">공동체 Dashboard를 불러오는 중입니다.</div>;

  const activeInvite = invites.some((invite) => invite.status === "active");
  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">Community · {role}</p>
          <div className="title-with-status"><h1>{community.name}</h1><CommunityStatusBadge status={community.status} /></div>
          <p className="muted">{community.description || "공동체 운영 정보를 확인합니다."}</p>
        </div>
        <Link className="button primary" href={`/admin/community/${community.id}`}>공동체 열기</Link>
      </div>

      <section className="card-grid">
        <Metric label="멤버" value={community.memberCount ?? 0} description="공동체 memberCount" />
        <Metric
          label="초대"
          value={role === "admin" ? (activeInvite ? "활성" : "없음") : "읽기 전용"}
          description={role === "admin"
            ? community.inviteEnabled === false ? "초대 허용 꺼짐" : "초대 운영 상태"
            : "초대 lifecycle은 공동체 관리자가 운영합니다."}
        />
        <Metric
          label="Primary Leader"
          value={community.primaryLeaderUid ? shortUid(community.primaryLeaderUid) : "미지정"}
          description="운영 대표 식별자"
        />
      </section>

      <section className="page-card page-stack compact-stack">
        <div>
          <p className="eyebrow">Content</p>
          <h2>Community Daily QT</h2>
          <p className="muted">이 공동체의 오늘 묵상 콘텐츠를 작성하고 게시합니다.</p>
        </div>
        <div className="button-row">
          <Link className="button primary" href={`/admin/community/${community.id}/qt`}>
            Daily QT 열기
          </Link>
        </div>
      </section>

      <section className="page-card metadata-grid">
        <Metadata label="시간대" value={community.timezone} />
        <Metadata label="생성일" value={formatDateTime(community.createdAt)} />
        <Metadata label="수정일" value={formatDateTime(community.updatedAt)} />
        <Metadata label="Community ID" value={community.id} />
      </section>
    </div>
  );
}

function Metric({ label, value, description }: { label: string; value: string | number; description: string }) {
  return <div className="metric-card"><span>{label}</span><strong>{value}</strong><p>{description}</p></div>;
}

function Metadata({ label, value }: { label: string; value: string }) {
  return <div className="metadata-card"><span>{label}</span><strong>{value}</strong></div>;
}
