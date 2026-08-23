"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { StatusBadge } from "@/components/StatusBadge";
import { formatDisplayDate } from "@/lib/date";
import { getDashboardSummary } from "@/lib/dailyQuietTimes";
import type { DailyQuietTime } from "@/types/dailyQuietTime";

type Summary = {
  today: string;
  todayContent: DailyQuietTime | null;
  weeklyCount: number;
  weeklyPublishedCount: number;
};

export default function AdminDashboardPage() {
  const [summary, setSummary] = useState<Summary | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getDashboardSummary()
      .then(setSummary)
      .catch((dashboardError) => setError(friendlyErrorMessage(dashboardError)));
  }, []);

  if (error) {
    return <div className="alert error">{error}</div>;
  }

  if (!summary) {
    return <div className="page-card">Dashboard를 불러오는 중입니다.</div>;
  }

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">{formatDisplayDate(summary.today)}</p>
          <h1>Dashboard</h1>
        </div>
        <Link className="button primary" href="/admin/qt/new">
          새 QT 작성
        </Link>
      </div>

      <section className="card-grid">
        <div className="metric-card">
          <span>오늘 QT</span>
          <strong>{summary.todayContent ? summary.todayContent.title : "없음"}</strong>
          {summary.todayContent ? (
            <>
              <p>{summary.todayContent.reference}</p>
              <StatusBadge status={summary.todayContent.status} />
            </>
          ) : (
            <p>오늘 날짜의 QT가 없습니다.</p>
          )}
        </div>
        <div className="metric-card">
          <span>이번 주 작성 QT</span>
          <strong>{summary.weeklyCount}</strong>
          <p>dailyQuietTimes 기준</p>
        </div>
        <div className="metric-card">
          <span>이번 주 Published</span>
          <strong>{summary.weeklyPublishedCount}</strong>
          <p>사용자에게 공개된 QT</p>
        </div>
      </section>
    </div>
  );
}
