"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAdminAuth } from "@/lib/auth";

export default function LoginPage() {
  const router = useRouter();
  const { state, error, isConfigured, signIn } = useAdminAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (state === "admin") {
      router.replace("/admin");
    }
  }, [router, state]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError(null);

    if (!email.trim() || !password) {
      setFormError("이메일과 비밀번호를 입력해주세요.");
      return;
    }

    setIsSubmitting(true);
    try {
      await signIn(email.trim(), password);
    } catch {
      setFormError("로그인하지 못했습니다. 이메일과 비밀번호를 확인해주세요.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="login-screen">
      <section className="login-card">
        <p className="eyebrow">VerseGarden Admin</p>
        <h1>관리자 로그인</h1>
        <p className="muted">Daily QT 콘텐츠를 작성하고 발행합니다.</p>

        {!isConfigured ? (
          <div className="alert error">Firebase Web 설정을 `.env.local`에 입력해주세요.</div>
        ) : null}
        {state === "denied" ? (
          <div className="alert error">이 계정은 관리자 권한이 없습니다.</div>
        ) : null}
        {error ? <div className="alert error">{error}</div> : null}
        {formError ? <div className="alert error">{formError}</div> : null}

        <form className="login-form" onSubmit={(event) => void handleSubmit(event)}>
          <label htmlFor="email">이메일</label>
          <input
            id="email"
            className="input"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />

          <label htmlFor="password">비밀번호</label>
          <input
            id="password"
            className="input"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />

          <button className="button primary full" disabled={isSubmitting || !isConfigured}>
            {isSubmitting ? "확인 중" : "로그인"}
          </button>
        </form>
      </section>
    </main>
  );
}
