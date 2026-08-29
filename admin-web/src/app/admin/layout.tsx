import { Suspense } from "react";
import { AdminShell } from "@/components/AdminShell";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<main className="center-screen">관리자 화면을 준비하고 있습니다.</main>}>
      <AdminShell>{children}</AdminShell>
    </Suspense>
  );
}
