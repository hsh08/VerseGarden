import { useEffect, useRef } from "react";
import { Redirect, Tabs } from "expo-router";

import { useAuthSession } from "@/providers/AuthSessionProvider";
import { traceStartup } from "@/services/diagnostics/startupTimeline";
import { colors, typography } from "@/theme/tokens";

export default function TabsLayout() {
  const { phase } = useAuthSession();
  const hasRecordedFirstTabPress = useRef(false);
  useEffect(() => { traceStartup("Tabs mounted"); }, []);
  if (phase !== "ready") return <Redirect href="/" />;
  return <Tabs initialRouteName="home" screenListeners={{ tabPress: (event) => { if (__DEV__) console.info("[Tab Press]", { route: event.target?.split("-")[0] ?? "unknown" }); if (!hasRecordedFirstTabPress.current) { hasRecordedFirstTabPress.current = true; traceStartup("First tab press received"); } } }} screenOptions={{ headerShown: false, tabBarActiveTintColor: colors.forestGreen, tabBarInactiveTintColor: colors.secondaryText, tabBarStyle: { backgroundColor: colors.cardBackground, borderTopColor: colors.border }, tabBarLabelStyle: { ...typography.caption, fontWeight: "600" }, tabBarHideOnKeyboard: true }}><Tabs.Screen name="verse" options={{ title: "Verse" }} /><Tabs.Screen name="prayer" options={{ title: "Prayer" }} /><Tabs.Screen name="home" options={{ title: "Home" }} /><Tabs.Screen name="garden" options={{ title: "Garden" }} /><Tabs.Screen name="profile" options={{ title: "Profile" }} /></Tabs>;
}
