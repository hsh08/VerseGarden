import { Timestamp, collection, getDocs, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { memberDisplayName, shortUid } from "@/lib/memberIdentity";
import type { CommunityMembership } from "@/types/community";
import type {
  CommunityQTSubmission,
  ParticipationMember,
  ParticipationSummary
} from "@/types/communityParticipation";

const SUPPORTED_SCHEMA_VERSION = 1;

export async function listCommunityQTSubmissions(
  communityId: string,
  dateKey: string
): Promise<CommunityQTSubmission[]> {
  const snapshot = await getDocs(
    query(
      collection(db, "communities", communityId, "qtSubmissions"),
      where("dateKey", "==", dateKey)
    )
  );

  return snapshot.docs.flatMap((item) => {
    const submission = parseSubmission(item.id, item.data(), communityId, dateKey);
    if (!submission && process.env.NODE_ENV !== "production") {
      console.warn("Skipped malformed Community QT submission", {
        submissionId: item.id,
        communityId,
        dateKey
      });
    }
    return submission ? [submission] : [];
  });
}

export function deriveParticipation(
  memberships: CommunityMembership[],
  submissions: CommunityQTSubmission[]
): ParticipationSummary {
  const activeMembers = memberships.filter(
    (member) => member.status === "active" && ["member", "leader", "admin"].includes(member.role)
  );
  const activeUIDs = new Set(activeMembers.map((member) => member.uid));
  const submissionByUID = new Map<string, CommunityQTSubmission>();

  for (const submission of submissions) {
    if (!activeUIDs.has(submission.uid)) continue;
    const current = submissionByUID.get(submission.uid);
    if (!current || submission.completedAt.toMillis() < current.completedAt.toMillis()) {
      if (current && process.env.NODE_ENV !== "production") {
        console.warn("Deduplicated Community QT submissions for member", {
          uid: shortUid(submission.uid),
          communityId: submission.communityId,
          dateKey: submission.dateKey
        });
      }
      submissionByUID.set(submission.uid, submission);
    }
  }

  const members = activeMembers
    .map((membership): ParticipationMember => {
      const submission = submissionByUID.get(membership.uid) ?? null;
      return {
        uid: membership.uid,
        displayName: participationDisplayName(membership, submission),
        membership,
        submission,
        status: submission ? "completed" : "incomplete"
      };
    })
    .sort((left, right) => left.displayName.localeCompare(right.displayName, "ko"));
  const completedMembers = members.filter((member) => member.status === "completed");
  const incompleteMembers = members.filter((member) => member.status === "incomplete");

  return {
    totalEligible: members.length,
    completedCount: completedMembers.length,
    incompleteCount: incompleteMembers.length,
    participationRate: members.length ? (completedMembers.length / members.length) * 100 : null,
    completedMembers,
    incompleteMembers
  };
}

function parseSubmission(
  id: string,
  data: Record<string, unknown>,
  expectedCommunityId: string,
  expectedDateKey: string
): CommunityQTSubmission | null {
  if (
    data.schemaVersion !== SUPPORTED_SCHEMA_VERSION ||
    data.communityId !== expectedCommunityId ||
    data.dateKey !== expectedDateKey ||
    data.contentSource !== "community" ||
    typeof data.uid !== "string" ||
    !data.uid ||
    typeof data.displayName !== "string" ||
    typeof data.contentId !== "string" ||
    typeof data.contentVersion !== "number" ||
    !Number.isInteger(data.contentVersion) ||
    data.contentVersion < 1 ||
    typeof data.reflectionAnswer !== "string" ||
    typeof data.applicationText !== "string" ||
    !(data.completedAt instanceof Timestamp)
  ) {
    return null;
  }

  return {
    id,
    uid: data.uid,
    displayName: data.displayName,
    communityId: expectedCommunityId,
    dateKey: expectedDateKey,
    contentId: data.contentId,
    contentVersion: data.contentVersion,
    contentSource: "community",
    reflectionAnswer: data.reflectionAnswer,
    applicationText: data.applicationText,
    completedAt: data.completedAt,
    schemaVersion: 1
  };
}

function participationDisplayName(
  membership: CommunityMembership,
  submission: CommunityQTSubmission | null
): string {
  const membershipName = memberDisplayName(membership);
  if (membershipName !== "사용자") return membershipName;
  const submissionName = submission?.displayName.trim();
  if (submissionName) return submissionName;
  return `사용자 ${shortUid(membership.uid)}`;
}
