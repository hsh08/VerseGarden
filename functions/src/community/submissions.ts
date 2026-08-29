import { createHash } from "node:crypto";
import { FieldValue, getFirestore, Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireAuth } from "./authorization.js";
import type {
  CallableAuth,
  CommunityDoc,
  CommunityRole,
  MembershipDoc
} from "./types.js";

const ALLOWED_INPUT_FIELDS = new Set([
  "communityId",
  "dateKey",
  "contentId",
  "contentVersion",
  "reflectionAnswer",
  "applicationText"
]);
const COMMUNITY_ROLES: CommunityRole[] = ["member", "leader", "admin"];
const MAX_IDENTIFIER_LENGTH = 256;
const MAX_SHARED_ANSWER_LENGTH = 20_000;
const SCHEMA_VERSION = 1;

type SubmitCommunityQTInput = {
  communityId?: unknown;
  dateKey?: unknown;
  contentId?: unknown;
  contentVersion?: unknown;
  reflectionAnswer?: unknown;
  applicationText?: unknown;
};

type CommunityDailyQuietTimeDoc = {
  communityId: string;
  dateKey: string;
  status: string;
  version: number;
};

export type CommunityQTSubmissionDoc = {
  uid: string;
  displayName: string;
  communityId: string;
  dateKey: string;
  contentId: string;
  contentVersion: number;
  contentSource: "community";
  reflectionAnswer: string;
  applicationText: string;
  completedAt: Timestamp | FieldValue;
  schemaVersion: 1;
};

export type SubmitCommunityQTResult = {
  success: true;
  alreadySubmitted: boolean;
  submissionId: string;
  communityId: string;
  dateKey: string;
  contentVersion: number;
};

function requirePlainInput(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Submission data is invalid.");
  }

  const input = value as Record<string, unknown>;
  const unknownFields = Object.keys(input).filter((key) => !ALLOWED_INPUT_FIELDS.has(key));
  if (unknownFields.length > 0) {
    throw new HttpsError("invalid-argument", "Submission contains unsupported fields.");
  }
  return input;
}

function requireIdentifier(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a string.`);
  }

  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > MAX_IDENTIFIER_LENGTH) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function requireDateKey(value: unknown): string {
  const dateKey = requireIdentifier(value, "dateKey");
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey);
  if (!match) {
    throw new HttpsError("invalid-argument", "dateKey is invalid.");
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    throw new HttpsError("invalid-argument", "dateKey is invalid.");
  }
  return dateKey;
}

function requireVersion(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw new HttpsError("invalid-argument", "contentVersion must be a positive integer.");
  }
  return value;
}

function requireSharedAnswer(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} must be a string.`);
  }

  const normalized = value.trim();
  if (normalized.length > MAX_SHARED_ANSWER_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be ${MAX_SHARED_ANSWER_LENGTH} characters or fewer.`
    );
  }
  return normalized;
}

function submissionIdFor(communityId: string, dateKey: string, uid: string): string {
  return createHash("sha256")
    .update(`${communityId}:${dateKey}:${uid}`, "utf8")
    .digest("hex");
}

function resolvedDisplayName(membership: MembershipDoc, uid: string): string {
  const displayName = membership.displayName?.trim();
  return displayName ? displayName.slice(0, 80) : `사용자 ${uid.slice(0, 8)}`;
}

function assertMembership(
  membership: MembershipDoc | undefined,
  uid: string
): asserts membership is MembershipDoc {
  if (
    !membership ||
    membership.uid !== uid ||
    membership.status !== "active" ||
    !COMMUNITY_ROLES.includes(membership.role)
  ) {
    throw new HttpsError("permission-denied", "Active community membership is required.");
  }
}

function assertCommunityQT(
  content: CommunityDailyQuietTimeDoc | undefined,
  communityId: string,
  dateKey: string,
  contentId: string,
  submittedVersion: number
) {
  if (!content) {
    throw new HttpsError("not-found", "Community QT not found.");
  }
  if (
    content.communityId !== communityId ||
    content.dateKey !== dateKey ||
    contentId !== dateKey
  ) {
    throw new HttpsError("failed-precondition", "Community QT identity is inconsistent.");
  }
  if (content.status !== "published") {
    throw new HttpsError("failed-precondition", "Community QT is not published.");
  }
  if (!Number.isInteger(content.version) || submittedVersion > content.version) {
    throw new HttpsError("failed-precondition", "Community QT version is invalid.");
  }
}

export async function submitCommunityQTCore(
  db: Firestore,
  authInput: CallableAuth,
  rawInput: unknown
): Promise<SubmitCommunityQTResult> {
  const auth = requireAuth(authInput);
  const raw = requirePlainInput(rawInput);
  const input = raw as SubmitCommunityQTInput;
  const communityId = requireIdentifier(input.communityId, "communityId");
  const dateKey = requireDateKey(input.dateKey);
  const contentId = requireIdentifier(input.contentId, "contentId");
  const contentVersion = requireVersion(input.contentVersion);
  const reflectionAnswer = requireSharedAnswer(input.reflectionAnswer, "reflectionAnswer");
  const applicationText = requireSharedAnswer(input.applicationText, "applicationText");
  if (contentId !== dateKey) {
    throw new HttpsError("failed-precondition", "Community QT identity is inconsistent.");
  }
  const submissionId = submissionIdFor(communityId, dateKey, auth.uid);

  const communityRef = db.collection("communities").doc(communityId);
  const membershipRef = communityRef.collection("members").doc(auth.uid);
  const contentRef = communityRef.collection("dailyQuietTimes").doc(dateKey);
  const submissionRef = communityRef.collection("qtSubmissions").doc(submissionId);

  return db.runTransaction(async (transaction) => {
    const [communitySnapshot, membershipSnapshot, contentSnapshot, submissionSnapshot] =
      await transaction.getAll(communityRef, membershipRef, contentRef, submissionRef);

    if (!communitySnapshot.exists) {
      throw new HttpsError("not-found", "Community not found.");
    }
    const community = communitySnapshot.data() as CommunityDoc;
    if (community.status !== "active") {
      throw new HttpsError("failed-precondition", "Community is not active.");
    }

    const membership = membershipSnapshot.exists
      ? membershipSnapshot.data() as MembershipDoc
      : undefined;
    assertMembership(membership, auth.uid);

    if (submissionSnapshot.exists) {
      const existing = submissionSnapshot.data() as CommunityQTSubmissionDoc;
      if (
        existing.uid !== auth.uid ||
        existing.communityId !== communityId ||
        existing.dateKey !== dateKey ||
        existing.contentId !== contentId ||
        existing.contentSource !== "community"
      ) {
        throw new HttpsError("failed-precondition", "Existing submission identity is invalid.");
      }
      return {
        success: true,
        alreadySubmitted: true,
        submissionId,
        communityId,
        dateKey,
        contentVersion: existing.contentVersion
      };
    }

    const content = contentSnapshot.exists
      ? contentSnapshot.data() as CommunityDailyQuietTimeDoc
      : undefined;
    assertCommunityQT(content, communityId, dateKey, contentId, contentVersion);

    const payload: CommunityQTSubmissionDoc = {
      uid: auth.uid,
      displayName: resolvedDisplayName(membership, auth.uid),
      communityId,
      dateKey,
      contentId,
      contentVersion,
      contentSource: "community",
      reflectionAnswer,
      applicationText,
      completedAt: FieldValue.serverTimestamp(),
      schemaVersion: SCHEMA_VERSION
    };
    transaction.create(submissionRef, payload);

    return {
      success: true,
      alreadySubmitted: false,
      submissionId,
      communityId,
      dateKey,
      contentVersion
    };
  });
}

export const submitCommunityQT = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => submitCommunityQTCore(getFirestore(), request.auth, request.data)
);
