import type { Metadata } from "next";
import "./globals.css";
import { AdminAuthProvider } from "@/lib/auth";

export const metadata: Metadata = {
  title: "VerseGarden Admin",
  description: "Daily QT CMS for VerseGarden"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <AdminAuthProvider>{children}</AdminAuthProvider>
      </body>
    </html>
  );
}
