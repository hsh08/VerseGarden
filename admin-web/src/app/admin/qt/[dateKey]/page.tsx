"use client";

import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { DailyQuietTimeForm } from "@/components/DailyQuietTimeForm";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { formStateFromContent, getDailyQuietTime } from "@/lib/dailyQuietTimes";
import type { DailyQuietTime, DailyQuietTimeFormState } from "@/types/dailyQuietTime";

export default function EditDailyQuietTimePage() {
  const params = useParams<{ dateKey: string }>();
  const [content, setContent] = useState<DailyQuietTime | null>(null);
  const [form, setForm] = useState<DailyQuietTimeFormState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    getDailyQuietTime(params.dateKey)
      .then((item) => {
        if (!item) {
          setError("해당 날짜에 등록된 QT가 없습니다.");
          return;
        }
        setContent(item);
        setForm(formStateFromContent(item));
      })
      .catch((loadError) => setError(friendlyErrorMessage(loadError)))
      .finally(() => setIsLoading(false));
  }, [params.dateKey]);

  if (isLoading) {
    return <div className="page-card">QT를 불러오는 중입니다.</div>;
  }

  if (error || !content || !form) {
    return <div className="alert error">{error ?? "QT 데이터를 찾지 못했습니다."}</div>;
  }

  return <DailyQuietTimeForm mode="edit" initialContent={content} initialForm={form} />;
}
