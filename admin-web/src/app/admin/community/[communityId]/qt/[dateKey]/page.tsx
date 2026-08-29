"use client";

import { useParams } from "next/navigation";
import { CommunityDailyQuietTimeScreen } from "@/components/CommunityDailyQuietTimeScreen";

export default function EditCommunityDailyQuietTimePage() {
  const params = useParams<{ communityId: string; dateKey: string }>();
  return (
    <CommunityDailyQuietTimeScreen
      communityId={params.communityId}
      dateKey={params.dateKey}
      mode="edit"
    />
  );
}
