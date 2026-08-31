import { Redirect, Stack } from "expo-router";

import { useAuthSession } from "@/providers/AuthSessionProvider";

export default function AuthLayout() {
  const { phase } = useAuthSession();
  if (phase !== "signedOut") return <Redirect href="/" />;
  return <Stack screenOptions={{ headerShown: false }} />;
}
