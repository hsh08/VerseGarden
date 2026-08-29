"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { StatusBadge } from "@/components/StatusBadge";
import { useAdminAuth } from "@/lib/auth";
import { formatDateTime } from "@/lib/date";
import { listDailyQuietTimes } from "@/lib/dailyQuietTimes";
import type {
  DailyQuietTime,
  DailyQuietTimeScope,
  DailyQuietTimeStatus
} from "@/types/dailyQuietTime";

const filters: Array<DailyQuietTimeStatus | "all"> = [
  "all",
  "draft",
  "published",
  "archived"
];

export function DailyQuietTimeList({ scope }: { scope?: DailyQuietTimeScope }) {
  const { state, communityScopes } = useAdminAuth();
  const [status, setStatus] = useState<DailyQuietTimeStatus | "all">("all");
  const [items, setItems] = useState<DailyQuietTime[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const baseHref = scope ? `/admin/community/${scope.communityId}/qt` : "/admin/qt";
  const isWritable = !scope || scope.communityStatus === "active";
  const canViewParticipation = Boolean(
    scope &&
    state === "communityAdmin" &&
    communityScopes.some((item) => item.communityId === scope.communityId)
  );

  useEffect(() => {
    setIsLoading(true);
    setError(null);
    listDailyQuietTimes(scope)
      .then(setItems)
      .catch((listError) => setError(friendlyErrorMessage(listError)))
      .finally(() => setIsLoading(false));
  }, [scope]);

  const filteredItems = useMemo(() => {
    if (status === "all") return items;
    return items.filter((item) => item.status === status);
  }, [items, status]);

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">
            {scope ? scope.communityName : "VerseGarden Global Daily QT"}
          </p>
          <h1>{scope ? "Community Daily QT" : "QT 목록"}</h1>
          {scope ? <p className="muted">{scope.timezone} 기준 공동체 묵상 콘텐츠</p> : null}
        </div>
        {isWritable ? (
          <Link className="button primary" href={`${baseHref}/new`}>
            새 QT 작성
          </Link>
        ) : null}
      </div>

      {scope && !isWritable ? (
        <div className="status-note">
          <p>
            현재 공동체는 {scope.communityStatus} 상태입니다. QT 이력은 조회할 수 있지만
            새 콘텐츠 작성과 상태 변경은 제한됩니다.
          </p>
        </div>
      ) : null}

      <div className="filter-row">
        {filters.map((filter) => (
          <button
            key={filter}
            className={`filter-button ${status === filter ? "active" : ""}`}
            type="button"
            onClick={() => setStatus(filter)}
          >
            {filter === "all" ? "All" : filter}
          </button>
        ))}
      </div>

      {error ? <div className="alert error">{error}</div> : null}
      {isLoading ? <div className="page-card">QT 목록을 불러오는 중입니다.</div> : null}
      {!isLoading && !filteredItems.length ? (
        <div className="empty-state prominent-empty">
          <strong>
            {status === "all"
              ? scope
                ? "아직 등록된 공동체 QT가 없습니다."
                : "등록된 QT가 없습니다."
              : `${status} 상태의 QT가 없습니다.`}
          </strong>
          {status === "all" && isWritable ? (
            <Link className="button primary" href={`${baseHref}/new`}>
              {scope ? "첫 QT 만들기" : "새 QT 작성"}
            </Link>
          ) : null}
        </div>
      ) : null}

      {filteredItems.length ? (
        <div className="table-card">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Title</th>
                <th>Bible Verse</th>
                <th>Status</th>
                <th>Version</th>
                <th>Updated At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={item.dateKey}>
                  <td>{item.dateKey}</td>
                  <td>{item.title}</td>
                  <td>{item.reference}</td>
                  <td><StatusBadge status={item.status} /></td>
                  <td>{item.version}</td>
                  <td>{formatDateTime(item.updatedAt)}</td>
                  <td>
                    <div className="table-row-actions">
                      <Link
                        className="button secondary compact-action"
                        href={`${baseHref}/${item.dateKey}`}
                      >
                        {isWritable ? "편집" : "보기"}
                      </Link>
                      {canViewParticipation && item.status === "published" ? (
                        <Link
                          className="button secondary compact-action"
                          href={`/admin/community/${scope?.communityId}/participation?date=${item.dateKey}`}
                        >
                          참여 현황
                        </Link>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </div>
  );
}
