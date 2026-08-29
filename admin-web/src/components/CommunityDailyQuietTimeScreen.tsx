"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { DailyQuietTimeForm } from "@/components/DailyQuietTimeForm";
import { DailyQuietTimeList } from "@/components/DailyQuietTimeList";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { getCommunity } from "@/lib/communities";
import { formStateFromContent, getDailyQuietTime } from "@/lib/dailyQuietTimes";
import type { Community } from "@/types/community";
import type {
  DailyQuietTime,
  DailyQuietTimeFormState,
  DailyQuietTimeScope
} from "@/types/dailyQuietTime";

type Props = {
  communityId: string;
  mode: "list" | "create" | "edit";
  dateKey?: string;
};

export function CommunityDailyQuietTimeScreen({ communityId, mode, dateKey }: Props) {
  const [community, setCommunity] = useState<Community | null>(null);
  const [content, setContent] = useState<DailyQuietTime | null>(null);
  const [form, setForm] = useState<DailyQuietTimeFormState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isCancelled = false;

    async function load() {
      setIsLoading(true);
      setError(null);
      try {
        const nextCommunity = await getCommunity(communityId);
        if (!nextCommunity) {
          throw new Error("공동체를 찾을 수 없습니다.");
        }
        if (isCancelled) return;
        setCommunity(nextCommunity);

        if (mode === "edit") {
          if (!dateKey) throw new Error("QT 날짜를 확인할 수 없습니다.");
          const scope = scopeFromCommunity(nextCommunity);
          const nextContent = await getDailyQuietTime(dateKey, scope);
          if (!nextContent) throw new Error("해당 날짜에 등록된 공동체 QT가 없습니다.");
          if ((nextContent as DailyQuietTime & { communityId?: string }).communityId !== communityId) {
            throw new Error("공동체 QT 범위가 일치하지 않습니다.");
          }
          if (isCancelled) return;
          setContent(nextContent);
          setForm(formStateFromContent(nextContent));
        }
      } catch (loadError) {
        if (!isCancelled) setError(friendlyErrorMessage(loadError));
      } finally {
        if (!isCancelled) setIsLoading(false);
      }
    }

    void load();
    return () => {
      isCancelled = true;
    };
  }, [communityId, dateKey, mode]);

  const scope = useMemo(
    () => community ? scopeFromCommunity(community) : null,
    [community]
  );

  if (isLoading) return <div className="page-card">공동체 QT를 불러오는 중입니다.</div>;
  if (error || !community || !scope) {
    return <div className="alert error">{error ?? "공동체 정보를 찾지 못했습니다."}</div>;
  }

  if (mode === "list") return <DailyQuietTimeList scope={scope} />;

  if (mode === "create") {
    if (community.status !== "active") {
      return (
        <div className="empty-state prominent-empty">
          <strong>현재 상태에서는 공동체 QT를 만들 수 없습니다.</strong>
          <p>비활성 또는 보관된 공동체는 QT 이력만 조회할 수 있습니다.</p>
          <Link className="button secondary" href={`/admin/community/${communityId}/qt`}>
            QT 목록으로
          </Link>
        </div>
      );
    }
    return <DailyQuietTimeForm mode="create" scope={scope} />;
  }

  if (!content || !form) {
    return <div className="alert error">QT 데이터를 찾지 못했습니다.</div>;
  }

  return (
    <DailyQuietTimeForm
      mode="edit"
      initialContent={content}
      initialForm={form}
      scope={scope}
    />
  );
}

function scopeFromCommunity(community: Community): DailyQuietTimeScope {
  return {
    communityId: community.id,
    communityName: community.name,
    communityStatus: community.status,
    timezone: community.timezone
  };
}
