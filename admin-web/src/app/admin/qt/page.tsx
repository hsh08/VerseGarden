"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { StatusBadge } from "@/components/StatusBadge";
import { formatDateTime } from "@/lib/date";
import { listDailyQuietTimes } from "@/lib/dailyQuietTimes";
import type { DailyQuietTime, DailyQuietTimeStatus } from "@/types/dailyQuietTime";

const filters: Array<DailyQuietTimeStatus | "all"> = ["all", "draft", "published", "archived"];

export default function DailyQuietTimeListPage() {
  const [status, setStatus] = useState<DailyQuietTimeStatus | "all">("all");
  const [items, setItems] = useState<DailyQuietTime[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setIsLoading(true);
    setError(null);
    listDailyQuietTimes()
      .then(setItems)
      .catch((listError) => setError(friendlyErrorMessage(listError)))
      .finally(() => setIsLoading(false));
  }, []);

  const filteredItems = useMemo(() => {
    if (status === "all") {
      return items;
    }

    return items.filter((item) => item.status === status);
  }, [items, status]);

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">Daily QT</p>
          <h1>QT 목록</h1>
        </div>
        <Link className="button primary" href="/admin/qt/new">
          새 QT 작성
        </Link>
      </div>

      <div className="filter-row">
        {filters.map((filter) => (
          <button
            key={filter}
            className={`filter-button ${status === filter ? "active" : ""}`}
            onClick={() => setStatus(filter)}
          >
            {filter === "all" ? "All" : filter}
          </button>
        ))}
      </div>

      {error ? <div className="alert error">{error}</div> : null}
      {isLoading ? <div className="page-card">QT 목록을 불러오는 중입니다.</div> : null}
      {!isLoading && !filteredItems.length ? (
        <div className="page-card">
          {status === "all" ? "등록된 QT가 없습니다." : `${status} 상태의 QT가 없습니다.`}
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
                  <td>
                    <StatusBadge status={item.status} />
                  </td>
                  <td>{item.version}</td>
                  <td>{formatDateTime(item.updatedAt)}</td>
                  <td>
                    <Link className="text-button" href={`/admin/qt/${item.dateKey}`}>
                      편집
                    </Link>
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
