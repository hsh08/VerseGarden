"use client";

import { FirebaseError } from "firebase/app";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { FormDialog } from "@/components/FormDialog";
import { useAdminAuth } from "@/lib/auth";
import { getCommunity, listCommunityMembers } from "@/lib/communities";
import {
  deriveParticipation,
  listCommunityQTSubmissions
} from "@/lib/communityParticipation";
import {
  formatDateTime,
  formatDisplayDate,
  isValidDateKey,
  todayDateKey
} from "@/lib/date";
import { listDailyQuietTimes } from "@/lib/dailyQuietTimes";
import { communityRoleLabel } from "@/lib/memberIdentity";
import type { Community, CommunityMembership } from "@/types/community";
import type {
  CommunityQTSubmission,
  ParticipationMember
} from "@/types/communityParticipation";
import type { DailyQuietTime, DailyQuietTimeScope } from "@/types/dailyQuietTime";

type ParticipationFilter = "all" | "completed" | "incomplete";

export function CommunityQTParticipationScreen({ communityId }: { communityId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { state, communityScopes } = useAdminAuth();
  const adminScope = communityScopes.find((item) => item.communityId === communityId);
  const canReadSubmissions =
    state === "communityAdmin" &&
    (adminScope?.role === "leader" || adminScope?.role === "admin");
  const [community, setCommunity] = useState<Community | null>(null);
  const [members, setMembers] = useState<CommunityMembership[]>([]);
  const [publishedContents, setPublishedContents] = useState<DailyQuietTime[]>([]);
  const [submissions, setSubmissions] = useState<CommunityQTSubmission[]>([]);
  const [filter, setFilter] = useState<ParticipationFilter>("all");
  const [selectedSubmission, setSelectedSubmission] = useState<ParticipationMember | null>(null);
  const [isLoadingBase, setIsLoadingBase] = useState(true);
  const [isLoadingSubmissions, setIsLoadingSubmissions] = useState(false);
  const [baseError, setBaseError] = useState<string | null>(null);
  const [submissionError, setSubmissionError] = useState<string | null>(null);

  useEffect(() => {
    if (!canReadSubmissions) {
      setIsLoadingBase(false);
      return;
    }

    let isCancelled = false;
    async function loadBaseData() {
      setIsLoadingBase(true);
      setBaseError(null);
      try {
        const nextCommunity = await getCommunity(communityId);
        if (!nextCommunity) throw new Error("공동체를 찾을 수 없습니다.");
        const scope = dailyQuietTimeScope(nextCommunity);
        const [contents, nextMembers] = await Promise.all([
          listDailyQuietTimes(scope),
          listCommunityMembers(communityId)
        ]);
        if (isCancelled) return;
        setCommunity(nextCommunity);
        setMembers(nextMembers);
        setPublishedContents(
          contents
            .filter((content) => content.status === "published")
            .sort((left, right) => right.dateKey.localeCompare(left.dateKey))
        );
      } catch (error) {
        if (!isCancelled) setBaseError(participationErrorMessage(error));
      } finally {
        if (!isCancelled) setIsLoadingBase(false);
      }
    }

    void loadBaseData();
    return () => {
      isCancelled = true;
    };
  }, [canReadSubmissions, communityId]);

  const today = community ? todayDateKey(community.timezone) : "";
  const requestedDate = searchParams.get("date");
  const selectedDateKey = requestedDate && isValidDateKey(requestedDate)
    ? requestedDate
    : today;
  const selectedContent = publishedContents.find(
    (content) => content.dateKey === selectedDateKey
  ) ?? null;
  const recentContents = useMemo(
    () => publishedContents.slice(0, 7),
    [publishedContents]
  );

  useEffect(() => {
    if (!canReadSubmissions || !community || isLoadingBase || !selectedContent) {
      setSubmissions([]);
      setIsLoadingSubmissions(false);
      setSubmissionError(null);
      return;
    }

    let isCancelled = false;
    setSubmissions([]);
    setIsLoadingSubmissions(true);
    setSubmissionError(null);
    listCommunityQTSubmissions(communityId, selectedContent.dateKey)
      .then((items) => {
        if (!isCancelled) setSubmissions(items);
      })
      .catch((error) => {
        if (!isCancelled) setSubmissionError(participationErrorMessage(error));
      })
      .finally(() => {
        if (!isCancelled) setIsLoadingSubmissions(false);
      });

    return () => {
      isCancelled = true;
    };
  }, [canReadSubmissions, community, communityId, isLoadingBase, selectedContent]);

  const summary = useMemo(
    () => deriveParticipation(members, submissions),
    [members, submissions]
  );
  const visibleMembers = useMemo(() => {
    if (filter === "completed") return summary.completedMembers;
    if (filter === "incomplete") return summary.incompleteMembers;
    return [...summary.completedMembers, ...summary.incompleteMembers];
  }, [filter, summary]);

  function selectDate(dateKey: string) {
    setFilter("all");
    setSelectedSubmission(null);
    router.replace(`/admin/community/${communityId}/participation?date=${dateKey}`, {
      scroll: false
    });
  }

  if (!canReadSubmissions) {
    return (
      <div className="empty-state prominent-empty">
        <strong>공동체 QT 참여 현황에 접근할 수 없습니다.</strong>
        <p>공유 답변은 해당 공동체의 활성 리더와 공동체 관리자만 볼 수 있습니다.</p>
        <Link className="button secondary" href="/admin">Dashboard로 돌아가기</Link>
      </div>
    );
  }
  if (isLoadingBase) return <div className="page-card">QT 참여 현황을 불러오는 중입니다.</div>;
  if (baseError) return <div className="alert error">{baseError}</div>;
  if (!community) return <div className="empty-state">공동체를 찾을 수 없습니다.</div>;

  return (
    <div className="page-stack participation-page">
      <div className="page-header">
        <div>
          <p className="eyebrow">{community.name}</p>
          <div className="title-with-status">
            <h1>QT 참여 현황</h1>
            <CommunityStatusBadge status={community.status} />
          </div>
          <p className="muted">{community.timezone} 기준 공동체 QT 참여를 확인합니다.</p>
        </div>
        <Link className="button secondary" href={`/admin/community/${communityId}/qt`}>
          Community QT
        </Link>
      </div>

      {community.status !== "active" ? (
        <div className="status-note">
          <p>현재 공동체는 {community.status} 상태입니다. 기존 참여 기록만 읽을 수 있습니다.</p>
        </div>
      ) : null}

      <section className="participation-history" aria-labelledby="participation-history-title">
        <div className="section-heading compact-heading">
          <div>
            <p className="eyebrow">History</p>
            <h2 id="participation-history-title">최근 게시된 공동체 QT</h2>
          </div>
        </div>
        {recentContents.length ? (
          <div className="participation-date-list">
            {recentContents.map((content) => (
              <button
                key={content.dateKey}
                type="button"
                className={`participation-date-button ${selectedDateKey === content.dateKey ? "active" : ""}`}
                aria-pressed={selectedDateKey === content.dateKey}
                onClick={() => selectDate(content.dateKey)}
              >
                <span>{formatDisplayDate(content.dateKey)}</span>
                <strong>{content.title}</strong>
              </button>
            ))}
          </div>
        ) : (
          <div className="empty-state">게시된 공동체 QT가 없습니다.</div>
        )}
        <p className="muted small">과거 참여율도 현재 활성 멤버를 기준으로 계산됩니다.</p>
      </section>

      {!selectedContent ? (
        <div className="empty-state prominent-empty">
          <strong>
            {selectedDateKey === today
              ? "오늘 게시된 공동체 QT가 없습니다."
              : "선택한 날짜에 게시된 공동체 QT가 없습니다."}
          </strong>
          <p>QT가 없는 날은 참여율 0%로 계산하지 않습니다.</p>
        </div>
      ) : (
        <>
          <section className="page-card participation-selected-qt">
            <div>
              <p className="eyebrow">{formatDisplayDate(selectedContent.dateKey)}</p>
              <h2>{selectedContent.title}</h2>
              <p className="muted">{selectedContent.reference}</p>
            </div>
            <span className="status-badge published">Published</span>
          </section>

          {submissionError ? <div className="alert error">{submissionError}</div> : null}
          {isLoadingSubmissions ? (
            <div className="page-card">선택한 날짜의 제출 기록을 불러오는 중입니다.</div>
          ) : (
            <>
              <section className="card-grid community-summary-grid participation-summary">
                <ParticipationMetric label="완료" value={`${summary.completedCount}명`} />
                <ParticipationMetric label="미완료" value={`${summary.incompleteCount}명`} />
                <ParticipationMetric
                  label="참여율"
                  value={summary.participationRate === null
                    ? "—"
                    : `${formatParticipationRate(summary.participationRate)}%`}
                />
                <ParticipationMetric label="참여 대상" value={`${summary.totalEligible}명`} />
              </section>

              <section className="page-card page-stack compact-stack">
                <div className="section-heading compact-heading">
                  <div>
                    <h2>멤버 참여 상태</h2>
                    <p className="muted">참여율은 현재 활성 멤버 기준입니다.</p>
                  </div>
                  <div className="filter-row" role="group" aria-label="참여 상태 필터">
                    {(["all", "completed", "incomplete"] as ParticipationFilter[]).map((item) => (
                      <button
                        key={item}
                        type="button"
                        className={`filter-button ${filter === item ? "active" : ""}`}
                        aria-pressed={filter === item}
                        onClick={() => setFilter(item)}
                      >
                        {{ all: "전체", completed: "완료", incomplete: "미완료" }[item]}
                      </button>
                    ))}
                  </div>
                </div>

                {summary.totalEligible === 0 ? (
                  <div className="empty-state">
                    <strong>참여 대상 0명</strong>
                    <p>현재 활성 상태인 공동체 멤버가 없습니다.</p>
                  </div>
                ) : (
                  <ParticipationTable
                    members={visibleMembers}
                    timeZone={community.timezone}
                    onOpenSubmission={setSelectedSubmission}
                  />
                )}
                <div className="participation-notes">
                  <p>이 기능 도입 이전의 완료 기록은 참여 현황에 포함되지 않을 수 있습니다.</p>
                  <p>탈퇴·제거·차단된 사용자는 현재 참여 대상과 참여율에서 제외됩니다.</p>
                </div>
              </section>
            </>
          )}
        </>
      )}

      <SubmissionDetailDialog
        member={selectedSubmission}
        dateKey={selectedContent?.dateKey ?? selectedDateKey}
        timeZone={community.timezone}
        onClose={() => setSelectedSubmission(null)}
      />
    </div>
  );
}

function ParticipationMetric({ label, value }: { label: string; value: string }) {
  return <div className="metric-card compact-metric"><span>{label}</span><strong>{value}</strong></div>;
}

function ParticipationTable({
  members,
  timeZone,
  onOpenSubmission
}: {
  members: ParticipationMember[];
  timeZone: string;
  onOpenSubmission: (member: ParticipationMember) => void;
}) {
  if (!members.length) return <div className="empty-state">선택한 상태의 멤버가 없습니다.</div>;

  return (
    <div className="table-card flat-card">
      <table>
        <thead><tr><th>멤버</th><th>역할</th><th>상태</th><th>완료 시각</th><th>답변</th></tr></thead>
        <tbody>
          {members.map((member) => (
            <tr key={member.uid}>
              <td><strong>{member.displayName}</strong></td>
              <td><span className="role-label">{communityRoleLabel(member.membership.role)}</span></td>
              <td>
                <span className={`participation-status ${member.status}`}>
                  {member.status === "completed" ? "완료" : "미완료"}
                </span>
              </td>
              <td>{member.submission ? formatDateTime(member.submission.completedAt, timeZone) : "—"}</td>
              <td>
                {member.submission ? (
                  <button className="button secondary compact-action" type="button" onClick={() => onOpenSubmission(member)}>
                    답변 보기
                  </button>
                ) : <span className="muted small">공유 답변 없음</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function SubmissionDetailDialog({
  member,
  dateKey,
  timeZone,
  onClose
}: {
  member: ParticipationMember | null;
  dateKey: string;
  timeZone: string;
  onClose: () => void;
}) {
  const submission = member?.submission ?? null;
  return (
    <FormDialog
      open={Boolean(member && submission)}
      title={member ? `${member.displayName}님의 QT 답변` : "QT 답변"}
      message="공동체 QT에서 공유된 묵상과 적용 답변만 표시됩니다. 기도 내용과 개인 기록은 공유되지 않습니다."
      onClose={onClose}
    >
      {submission ? (
        <div className="submission-detail">
          <div className="submission-detail-meta">
            <span>{formatDisplayDate(dateKey)}</span>
            <span>{formatDateTime(submission.completedAt, timeZone)}</span>
            <span>콘텐츠 버전 {submission.contentVersion}</span>
          </div>
          <SharedAnswer label="묵상" answer={submission.reflectionAnswer} />
          <SharedAnswer label="오늘의 적용" answer={submission.applicationText} />
        </div>
      ) : null}
    </FormDialog>
  );
}

function SharedAnswer({ label, answer }: { label: string; answer: string }) {
  return (
    <section className="shared-answer">
      <span>{label}</span>
      <p>{answer.trim() || "작성된 답변이 없습니다."}</p>
    </section>
  );
}

function dailyQuietTimeScope(community: Community): DailyQuietTimeScope {
  return {
    communityId: community.id,
    communityName: community.name,
    communityStatus: community.status,
    timezone: community.timezone
  };
}

function formatParticipationRate(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function participationErrorMessage(error: unknown): string {
  if (error instanceof FirebaseError) {
    if (error.code === "permission-denied") {
      return "공동체 QT 공유 답변을 볼 권한이 없습니다.";
    }
    if (error.code === "unavailable" || error.code === "deadline-exceeded") {
      return "네트워크 연결을 확인한 뒤 다시 시도해주세요.";
    }
  }
  return "QT 참여 현황을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.";
}
