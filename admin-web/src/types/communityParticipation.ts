import type { Timestamp } from "firebase/firestore";
import type { CommunityMembership } from "@/types/community";

export type CommunityQTSubmission = {
  id: string;
  uid: string;
  displayName: string;
  communityId: string;
  dateKey: string;
  contentId: string;
  contentVersion: number;
  contentSource: "community";
  reflectionAnswer: string;
  applicationText: string;
  completedAt: Timestamp;
  schemaVersion: 1;
};

export type ParticipationMember = {
  uid: string;
  displayName: string;
  membership: CommunityMembership;
  submission: CommunityQTSubmission | null;
  status: "completed" | "incomplete";
};

export type ParticipationSummary = {
  totalEligible: number;
  completedCount: number;
  incompleteCount: number;
  participationRate: number | null;
  completedMembers: ParticipationMember[];
  incompleteMembers: ParticipationMember[];
};
