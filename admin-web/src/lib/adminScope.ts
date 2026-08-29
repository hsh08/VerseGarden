import { FirebaseError } from "firebase/app";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import type { CommunityAdminScope, CommunityRole } from "@/types/community";

export async function getMyAdminCommunities(): Promise<CommunityAdminScope[]> {
  const callable = httpsCallable<void, { communities: CommunityAdminScope[] }>(
    functions,
    "getMyAdminCommunities"
  );
  const result = await callable();
  return result.data.communities;
}

export async function setCommunityMemberRole(
  communityId: string,
  targetUid: string,
  role: CommunityRole
): Promise<void> {
  try {
    const callable = httpsCallable<
      { communityId: string; targetUid: string; role: CommunityRole },
      { communityId: string; targetUid: string; role: CommunityRole }
    >(functions, "setCommunityMemberRole");
    await callable({ communityId, targetUid, role });
  } catch (error) {
    throw new Error(adminOperationErrorMessage(error));
  }
}

export function adminOperationErrorMessage(error: unknown): string {
  const code = error instanceof FirebaseError ? error.code.replace("functions/", "") : "";
  switch (code) {
    case "permission-denied":
    case "unauthenticated":
      return "이 역할을 변경할 권한이 없습니다.";
    case "failed-precondition":
      return "현재 상태에서는 역할을 변경할 수 없습니다.";
    case "not-found":
      return "공동체 또는 멤버 정보를 찾을 수 없습니다.";
    case "invalid-argument":
      return "역할 변경 정보를 확인해주세요.";
    default:
      return "요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.";
  }
}
