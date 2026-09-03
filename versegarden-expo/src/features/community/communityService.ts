import { httpsCallable } from "firebase/functions";

import { getFirebaseServices } from "@/services/firebase";
import { firebaseEnvironment } from "@/services/firebase/config";

import { parseCommunityMembership, type CommunityJoinResult, type CommunityMembership, type CommunitySubmissionRequest } from "./communityTypes";

function requireFunctions() {
  const functions = getFirebaseServices()?.functions;
  if (!functions) throw new Error("firebase-unavailable");
  return functions;
}

function logCallableFailure(functionName: string, error: unknown) {
  if (!__DEV__) return;

  const services = getFirebaseServices();
  const source = error instanceof Error ? error : null;
  const code = callableCode(error) || "unknown";
  const normalizedCode = code.replace(/^functions\//, "");

  console.error("[Community Callable Diagnostics]", {
    functionName,
    normalizedCode,
    firebaseFunctionsCode: code,
    message: source?.message ?? "Unknown callable failure",
    httpOrNetworkCategory: normalizedCode.includes("network") || normalizedCode === "unavailable" || normalizedCode === "deadline-exceeded" ? "network" : "callable",
    authUserExists: Boolean(services?.auth.currentUser),
    functionsRegion: firebaseEnvironment.functionsRegion,
    timestamp: new Date().toISOString(),
  });
}

function callableCode(error: unknown): string {
  return typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
}

export function communityErrorMessage(error: unknown, action: "load" | "join" | "submit"): string {
  const code = callableCode(error);
  if (code.includes("unauthenticated")) return "다시 로그인한 뒤 시도해주세요.";
  if (code.includes("permission-denied")) return action === "join" ? "이 공동체에 참여할 수 없습니다." : "공동체 정보를 확인할 권한이 없습니다.";
  if (code.includes("not-found") || code.includes("invalid-argument")) return action === "join" ? "유효하지 않은 초대 코드입니다." : "공동체 QT를 찾을 수 없습니다.";
  if (code.includes("failed-precondition") || code.includes("resource-exhausted")) return action === "join" ? "현재 사용할 수 없는 초대 코드입니다." : "현재 제출할 수 없는 공동체 QT입니다.";
  if (code.includes("unavailable") || code.includes("deadline-exceeded") || code.includes("network")) return "네트워크 연결을 확인한 뒤 다시 시도해주세요.";
  return action === "load" ? "공동체 정보를 불러오지 못했습니다." : action === "join" ? "공동체 참여 중 문제가 발생했습니다. 다시 시도해주세요." : "공동체 답변을 공유하지 못했습니다.";
}

export const communityService = {
  async getMyCommunities(): Promise<CommunityMembership[]> {
    try {
      const result = await httpsCallable<undefined, { communities?: unknown }>(requireFunctions(), "getMyCommunities")();
      if (!Array.isArray(result.data?.communities)) throw new Error("invalid-community-response");
      const parsed = result.data.communities.map(parseCommunityMembership);
      if (parsed.some((item) => item === null)) throw new Error("invalid-community-response");
      return (parsed as CommunityMembership[]).sort((left, right) => left.joinedAt.getTime() - right.joinedAt.getTime() || left.communityId.localeCompare(right.communityId));
    } catch (error) {
      logCallableFailure("getMyCommunities", error);
      throw error;
    }
  },
  async redeemInvite(rawCode: string): Promise<CommunityJoinResult> {
    try {
      const code = rawCode.trim().toUpperCase();
      if (!code) throw new Error("invalid-argument");
      const result = await httpsCallable<{ code: string }, { communityId?: unknown; name?: unknown; alreadyMember?: unknown }>(requireFunctions(), "redeemCommunityInvite")({ code });
      if (typeof result.data.communityId !== "string" || typeof result.data.name !== "string") throw new Error("invalid-community-response");
      return { communityId: result.data.communityId, communityName: result.data.name, alreadyMember: result.data.alreadyMember === true };
    } catch (error) {
      logCallableFailure("redeemCommunityInvite", error);
      throw error;
    }
  },
  async submitQT(request: CommunitySubmissionRequest): Promise<{ alreadySubmitted: boolean; submissionId: string }> {
    try {
      const result = await httpsCallable<CommunitySubmissionRequest, { success?: unknown; alreadySubmitted?: unknown; submissionId?: unknown }>(requireFunctions(), "submitCommunityQT")(request);
      if (result.data.success !== true || typeof result.data.submissionId !== "string") throw new Error("invalid-community-response");
      return { alreadySubmitted: result.data.alreadySubmitted === true, submissionId: result.data.submissionId };
    } catch (error) {
      logCallableFailure("submitCommunityQT", error);
      throw error;
    }
  },
};
