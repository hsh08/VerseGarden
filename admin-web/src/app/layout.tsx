import type { Metadata } from "next";
import "./globals.css";
import { GlobalLoadingProvider } from "@/components/GlobalLoadingProvider";
import { AdminAuthProvider } from "@/lib/auth";

export const metadata: Metadata = {
  title: "VerseGarden Admin",
  description: "Daily QT CMS for VerseGarden"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <AdminAuthProvider>
          <GlobalLoadingProvider>{children}</GlobalLoadingProvider>
        </AdminAuthProvider>
      </body>
    </html>
  );
}
