"use client";

import { useParams } from "next/navigation";
import { CommunityQTParticipationScreen } from "@/components/CommunityQTParticipationScreen";

export default function CommunityQTParticipationPage() {
  const params = useParams<{ communityId: string }>();
  return <CommunityQTParticipationScreen communityId={params.communityId} />;
}
