"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { formatDateTime } from "@/lib/date";
import { shortUid } from "@/lib/memberIdentity";
import { listCommunities } from "@/lib/communities";
import type { Community, CommunityStatus } from "@/types/community";

const filters: Array<CommunityStatus | "all"> = ["all", "active", "inactive", "archived"];

export default function CommunitiesPage() {
  const [communities, setCommunities] = useState<Community[]>([]);
  const [filter, setFilter] = useState<CommunityStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listCommunities()
      .then(setCommunities)
      .catch((listError) => setError(friendlyErrorMessage(listError)))
      .finally(() => setIsLoading(false));
  }, []);

  const summary = useMemo(
    () => ({
      total: communities.length,
      active: communities.filter((item) => item.status === "active").length,
      inactive: communities.filter((item) => item.status === "inactive").length,
      archived: communities.filter((item) => item.status === "archived").length
    }),
    [communities]
  );

  const filteredCommunities = useMemo(() => {
    const normalizedSearch = search.trim().toLocaleLowerCase("ko-KR");
    return communities.filter((community) => {
      const matchesStatus = filter === "all" || community.status === filter;
      const matchesSearch =
        !normalizedSearch ||
        community.name.toLocaleLowerCase("ko-KR").includes(normalizedSearch) ||
        (community.description ?? "").toLocaleLowerCase("ko-KR").includes(normalizedSearch);
      return matchesStatus && matchesSearch;
    });
  }, [communities, filter, search]);

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <p className="eyebrow">Platform</p>
          <h1>공동체</h1>
          <p className="muted">VerseGarden 공동체의 운영 상태와 멤버십을 관리합니다.</p>
        </div>
        <Link className="button primary" href="/admin/communities/new">
          + 새 공동체
        </Link>
      </div>

      <section className="card-grid community-summary-grid">
        <SummaryCard label="전체 공동체" value={summary.total} />
        <SummaryCard label="활성" value={summary.active} />
        <SummaryCard label="비활성" value={summary.inactive} />
        <SummaryCard label="보관" value={summary.archived} />
      </section>

      <section className="community-toolbar">
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
        <input
          className="input community-search"
          value={search}
          placeholder="공동체 이름 또는 설명 검색"
          aria-label="공동체 검색"
          onChange={(event) => setSearch(event.target.value)}
        />
      </section>

      {error ? <div className="alert error">{error}</div> : null}
      {isLoading ? <div className="page-card">공동체 목록을 불러오는 중입니다.</div> : null}
      {!isLoading && !communities.length ? (
        <div className="empty-state prominent-empty">
          <strong>아직 생성된 공동체가 없습니다.</strong>
          <Link className="button primary" href="/admin/communities/new">첫 공동체 만들기</Link>
        </div>
      ) : null}
      {!isLoading && communities.length && !filteredCommunities.length ? (
        <div className="empty-state">조건에 맞는 공동체가 없습니다.</div>
      ) : null}

      {filteredCommunities.length ? (
        <div className="table-card">
          <table>
            <thead>
              <tr>
                <th>Community</th>
                <th>Status</th>
                <th>Members</th>
                <th>Primary Leader</th>
                <th>Timezone</th>
                <th>Created At</th>
                <th>Updated At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredCommunities.map((community) => (
                <tr key={community.id}>
                  <td>
                    <strong>{community.name}</strong>
                    <span className="table-subtitle">{community.description || "설명 없음"}</span>
                  </td>
                  <td><CommunityStatusBadge status={community.status} /></td>
                  <td>{community.memberCount ?? "—"}</td>
                  <td className="metadata-value" title={community.primaryLeaderUid}>
                    {community.primaryLeaderUid ? shortUid(community.primaryLeaderUid) : "—"}
                  </td>
                  <td>{community.timezone}</td>
                  <td>{formatDateTime(community.createdAt)}</td>
                  <td>{formatDateTime(community.updatedAt)}</td>
                  <td>
                    <Link className="button secondary compact-action" href={`/admin/communities/${community.id}`}>
                      관리
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

function SummaryCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="metric-card compact-metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
