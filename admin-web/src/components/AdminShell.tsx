"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { AdminBrand } from "@/components/AdminBrand";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import { useAdminAuth } from "@/lib/auth";

const platformNavigation = [
  {
    label: "Overview",
    items: [{ href: "/admin", label: "Dashboard", exact: true }]
  },
  {
    label: "Content",
    items: [{ href: "/admin/qt", label: "Daily QT", exact: false }]
  },
  {
    label: "Platform",
    items: [{ href: "/admin/communities", label: "Communities", exact: false }]
  }
];

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const router = useRouter();
  const {
    state,
    user,
    error,
    communityScopes,
    selectedCommunityId,
    setSelectedCommunityId,
    signOutAdmin,
    refreshClaims
  } = useAdminAuth();
  const { withGlobalLoading } = useGlobalLoading();

  useEffect(() => {
    if (state === "signedOut") {
      router.replace("/login");
    }
  }, [router, state]);

  if (state === "loading" || state === "signedOut") {
    return <FullScreenMessage title="권한 확인 중" description="관리자 권한을 확인하고 있습니다." />;
  }

  if (state === "denied") {
    return (
      <FullScreenMessage
        title="관리 가능한 공동체가 없습니다"
        description={error ?? "이 계정에는 VerseGarden Admin에서 관리할 수 있는 범위가 없습니다."}
      >
        <button className="button secondary" onClick={refreshClaims}>
          권한 다시 확인
        </button>
        <button className="button danger" onClick={() => void withGlobalLoading(signOutAdmin, "로그아웃 중...")}>
          로그아웃
        </button>
      </FullScreenMessage>
    );
  }

  const scopedCommunityId = communityIdFromPath(pathname);
  const isScopedAdmin = state === "communityAdmin";
  const hasScopedRouteAccess =
    !isScopedAdmin ||
    pathname === "/admin" ||
    (scopedCommunityId !== null &&
      communityScopes.some((scope) => scope.communityId === scopedCommunityId));

  if (!hasScopedRouteAccess) {
    return (
      <FullScreenMessage
        title="접근할 수 없는 관리 영역입니다"
        description="선택한 계정의 공동체 관리 범위에서 이 페이지를 사용할 수 없습니다."
      >
        <Link className="button primary" href="/admin">Dashboard로 돌아가기</Link>
      </FullScreenMessage>
    );
  }

  const navigation =
    state === "platformAdmin"
      ? platformNavigation
      : communityNavigation(
          selectedCommunityId,
          communityScopes.find((scope) => scope.communityId === selectedCommunityId)?.role ?? null
        );
  const selectedCommunityRole = communityScopes.find(
    (scope) => scope.communityId === selectedCommunityId
  )?.role;

  function handleCommunityChange(communityId: string) {
    setSelectedCommunityId(communityId);
    if (pathname.startsWith("/admin/community/")) {
      router.push(`/admin/community/${communityId}`);
    }
  }

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <AdminBrand
          mode={state === "platformAdmin"
            ? "platform"
            : selectedCommunityRole === "admin" ? "community" : "leader"}
        />
        {state === "communityAdmin" && selectedCommunityId ? (
          <label className="community-switcher">
            <span className="sidebar-section-title">Community</span>
            <select
              value={selectedCommunityId}
              onChange={(event) => handleCommunityChange(event.target.value)}
              aria-label="관리할 공동체 선택"
            >
              {communityScopes.map((scope) => (
                <option key={scope.communityId} value={scope.communityId}>
                  {scope.communityName}
                </option>
              ))}
            </select>
          </label>
        ) : null}
        <nav className="sidebar-nav">
          {navigation.map((section) => (
            <div className="sidebar-nav-group" key={section.label}>
              <span className="sidebar-section-title">{section.label}</span>
              {section.items.map((item) => {
                const isActive = isNavigationActive(
                  pathname,
                  searchParams.get("tab"),
                  item.href,
                  item.exact
                );
                return (
                  <Link
                    key={item.href}
                    className={`sidebar-link ${isActive ? "active" : ""}`}
                    href={item.href}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>
        <div className="sidebar-section">
          <span className="sidebar-section-title">Settings</span>
          {state === "platformAdmin" ? (
            <>
              <span className="sidebar-disabled">Users</span>
              <span className="sidebar-disabled">Statistics</span>
            </>
          ) : (
            <span className="sidebar-disabled">Community Settings</span>
          )}
        </div>
        <div className="sidebar-account">
          <span>{user?.email}</span>
          <button className="text-button" onClick={() => void withGlobalLoading(signOutAdmin, "로그아웃 중...")}>
            로그아웃
          </button>
        </div>
      </aside>
      <main className="admin-main">{children}</main>
    </div>
  );
}

function communityNavigation(communityId: string | null, role: "leader" | "admin" | null) {
  const base = communityId ? `/admin/community/${communityId}` : "/admin";
  const sections = [
    {
      label: "Overview",
      items: [{ href: "/admin", label: "Dashboard", exact: true }]
    },
    {
      label: "Community",
      items: [
        { href: base, label: "Overview", exact: true },
        { href: `${base}?tab=members`, label: "Members", exact: true }
      ]
    },
    {
      label: "Content",
      items: [{ href: `${base}/qt`, label: "Daily QT", exact: false }]
    },
    {
      label: "Insights",
      items: [{ href: `${base}/participation`, label: "QT Participation", exact: false }]
    }
  ];
  if (role === "admin") {
    sections.push({
      label: "Operations",
      items: [{ href: `${base}?tab=invitation`, label: "Invitation", exact: true }]
    });
  }
  return sections;
}

function communityIdFromPath(pathname: string): string | null {
  const match = pathname.match(/^\/admin\/community\/([^/]+)(?:\/|$)/);
  return match ? decodeURIComponent(match[1]) : null;
}

function isNavigationActive(
  pathname: string,
  currentTab: string | null,
  href: string,
  exact: boolean
): boolean {
  const [hrefPath, queryString] = href.split("?");
  const hrefTab = queryString ? new URLSearchParams(queryString).get("tab") : null;
  if (hrefTab) {
    return pathname === hrefPath && currentTab === hrefTab;
  }
  if (hrefPath.startsWith("/admin/community/")) {
    return exact
      ? pathname === hrefPath && currentTab === null
      : pathname === hrefPath || pathname.startsWith(`${hrefPath}/`);
  }
  return exact ? pathname === hrefPath : pathname === hrefPath || pathname.startsWith(`${hrefPath}/`);
}

function FullScreenMessage({
  title,
  description,
  children
}: {
  title: string;
  description: string;
  children?: React.ReactNode;
}) {
  return (
    <main className="center-screen">
      <section className="message-card">
        <h1>{title}</h1>
        <p>{description}</p>
        {children ? <div className="button-row">{children}</div> : null}
      </section>
    </main>
  );
}
