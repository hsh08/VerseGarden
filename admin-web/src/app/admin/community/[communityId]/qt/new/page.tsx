"use client";

import { useParams } from "next/navigation";
import { CommunityDailyQuietTimeScreen } from "@/components/CommunityDailyQuietTimeScreen";

export default function NewCommunityDailyQuietTimePage() {
  const params = useParams<{ communityId: string }>();
  return <CommunityDailyQuietTimeScreen communityId={params.communityId} mode="create" />;
}
