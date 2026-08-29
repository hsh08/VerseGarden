import { FirebaseError } from "firebase/app";
import { Timestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import type { CommunityInviteSummary, GeneratedCommunityInvite } from "@/types/community";

type InviteIdentifier = { inviteId: string };

export async function createCommunityInvite(
  communityId: string
): Promise<GeneratedCommunityInvite> {
  try {
    const callable = httpsCallable<
      { communityId: string },
      GeneratedCommunityInvite
    >(functions, "createCommunityInvite");
    const result = await callable({ communityId });
    return result.data;
  } catch (error) {
    throw new Error(inviteErrorMessage(error));
  }
}

export async function revokeCommunityInvite(inviteId: string): Promise<void> {
  try {
    const callable = httpsCallable<InviteIdentifier, { status: "revoked" }>(
      functions,
      "revokeCommunityInvite"
    );
    await callable({ inviteId });
  } catch (error) {
    throw new Error(inviteErrorMessage(error));
  }
}

export async function regenerateCommunityInvite(
  inviteId: string
): Promise<GeneratedCommunityInvite> {
  try {
    const callable = httpsCallable<InviteIdentifier, GeneratedCommunityInvite>(
      functions,
      "regenerateCommunityInvite"
    );
    const result = await callable({ inviteId });
    return result.data;
  } catch (error) {
    throw new Error(inviteErrorMessage(error));
  }
}

type CallableInvite = Omit<
  CommunityInviteSummary,
  "id" | "createdAt" | "updatedAt" | "expiresAt" | "lastUsedAt"
> & {
  inviteId: string;
  createdAt: string;
  updatedAt: string;
  expiresAt?: string;
  lastUsedAt?: string;
};

export async function listManagedCommunityInvites(
  communityId: string
): Promise<CommunityInviteSummary[]> {
  try {
    const callable = httpsCallable<
      { communityId: string },
      { invites: CallableInvite[] }
    >(functions, "listManagedCommunityInvites");
    const result = await callable({ communityId });
    return result.data.invites.map((invite) => {
      const { inviteId, createdAt, updatedAt, expiresAt, lastUsedAt, ...rest } = invite;
      return {
        ...rest,
        id: inviteId,
        createdAt: Timestamp.fromDate(new Date(createdAt)),
        updatedAt: Timestamp.fromDate(new Date(updatedAt)),
        ...(expiresAt ? { expiresAt: Timestamp.fromDate(new Date(expiresAt)) } : {}),
        ...(lastUsedAt ? { lastUsedAt: Timestamp.fromDate(new Date(lastUsedAt)) } : {})
      };
    });
  } catch (error) {
    throw new Error(inviteErrorMessage(error));
  }
}

function inviteErrorMessage(error: unknown): string {
  const code = error instanceof FirebaseError ? error.code.replace("functions/", "") : "";
  switch (code) {
    case "permission-denied":
    case "unauthenticated":
      return "관리자 권한이 없습니다.";
    case "not-found":
      return "공동체 또는 초대 정보를 찾을 수 없습니다.";
    case "resource-exhausted":
      return "초대 사용 한도에 도달했습니다.";
    case "failed-precondition":
      return "현재 공동체 또는 초대 상태에서는 이 작업을 수행할 수 없습니다.";
    case "invalid-argument":
      return "초대 정보를 확인해주세요.";
    default:
      return "초대 요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.";
  }
}
