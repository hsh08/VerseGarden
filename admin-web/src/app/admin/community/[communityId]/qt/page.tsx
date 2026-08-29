"use client";

import { useParams } from "next/navigation";
import { CommunityDailyQuietTimeScreen } from "@/components/CommunityDailyQuietTimeScreen";

export default function CommunityDailyQuietTimeListPage() {
  const params = useParams<{ communityId: string }>();
  return <CommunityDailyQuietTimeScreen communityId={params.communityId} mode="list" />;
}
