import { Redirect } from "expo-router";

import { FullScreenState } from "@/components/feedback/FullScreenState";
import { useAuthSession } from "@/providers/AuthSessionProvider";

export default function RootIndex() {
  const { phase, errorMessage, retryProfile } = useAuthSession();
  if (phase === "initializing" || phase === "profileLoading") return <FullScreenState loading title={phase === "profileLoading" ? "프로필 정보를 불러오는 중..." : "VerseGarden을 준비하는 중..."} />;
  if (phase === "configurationError") return <FullScreenState description={errorMessage ?? "Expo Firebase 환경 설정을 확인해주세요."} title="Firebase 설정이 필요합니다" />;
  if (phase === "profileError") return <FullScreenState actionLabel="다시 시도" description={errorMessage ?? undefined} onAction={() => void retryProfile()} title="프로필을 불러오지 못했습니다" />;
  if (phase === "signedOut") return <Redirect href="/(auth)/login" />;
  if (phase === "onboardingRequired") return <Redirect href="/onboarding" />;
  return <Redirect href="/(tabs)/home" />;
}
