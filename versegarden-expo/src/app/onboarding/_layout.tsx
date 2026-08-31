import { Redirect, Stack } from "expo-router";

import { useAuthSession } from "@/providers/AuthSessionProvider";

export default function OnboardingLayout() {
  const { phase } = useAuthSession();
  if (phase !== "onboardingRequired") return <Redirect href="/" />;
  return <Stack screenOptions={{ headerShown: false }} />;
}
