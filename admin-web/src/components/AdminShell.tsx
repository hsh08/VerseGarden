"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAdminAuth } from "@/lib/auth";

const navigation = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/qt", label: "QT 목록" },
  { href: "/admin/qt/new", label: "새 QT 작성" }
];

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { state, user, error, signOutAdmin, refreshClaims } = useAdminAuth();

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
        title="관리자 권한이 없습니다"
        description={error ?? "이 계정은 VerseGarden Admin에 접근할 수 없습니다."}
      >
        <button className="button secondary" onClick={refreshClaims}>
          권한 다시 확인
        </button>
        <button className="button danger" onClick={() => void signOutAdmin()}>
          로그아웃
        </button>
      </FullScreenMessage>
    );
  }

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <span className="brand-title">VerseGarden</span>
          <span className="brand-subtitle">Admin</span>
        </div>
        <nav className="sidebar-nav">
          {navigation.map((item) => (
            <Link
              key={item.href}
              className={`sidebar-link ${pathname === item.href ? "active" : ""}`}
              href={item.href}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="sidebar-section">
          <span className="sidebar-section-title">향후 기능</span>
          <span className="sidebar-disabled">공동체</span>
          <span className="sidebar-disabled">사용자</span>
          <span className="sidebar-disabled">통계</span>
        </div>
        <div className="sidebar-account">
          <span>{user?.email}</span>
          <button className="text-button" onClick={() => void signOutAdmin()}>
            로그아웃
          </button>
        </div>
      </aside>
      <main className="admin-main">{children}</main>
    </div>
  );
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
