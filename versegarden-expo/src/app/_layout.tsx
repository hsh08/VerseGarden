import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";

import { AppBootstrapNotice } from "@/components/layout/AppBootstrapNotice";
import { AppProviders } from "@/providers/AppProviders";
import { VerseDeepLinkHandler } from "@/providers/VerseDeepLinkHandler";
import { colors } from "@/theme/tokens";

export default function RootLayout() {
  return (
    <AppProviders>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.background } }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="write/[verseId]" />
        <Stack.Screen name="qt/index" />
        <Stack.Screen name="prayer-record/new" />
        <Stack.Screen name="prayer-record/[recordId]" />
      </Stack>
      <VerseDeepLinkHandler />
      <AppBootstrapNotice />
    </AppProviders>
  );
}
