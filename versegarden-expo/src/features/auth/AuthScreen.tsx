import type { PropsWithChildren } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { colors, spacing, typography } from "@/theme/tokens";

type AuthScreenProps = PropsWithChildren<{ title: string; description: string }>;

export function AuthScreen({ title, description, children }: AuthScreenProps) {
  return <SafeAreaView edges={["top", "left", "right"]} style={styles.safeArea}><KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.flex}><ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled"><View style={styles.hero}><Text style={styles.brand}>VerseGarden</Text><Text style={styles.title}>{title}</Text><Text style={styles.description}>{description}</Text></View><View style={styles.form}>{children}</View></ScrollView></KeyboardAvoidingView></SafeAreaView>;
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  safeArea: { backgroundColor: colors.background, flex: 1 },
  content: { flexGrow: 1, gap: spacing.lg, justifyContent: "center", padding: spacing.screen },
  hero: { gap: spacing.xs },
  brand: { color: colors.forestGreen, ...typography.label },
  title: { color: colors.primaryText, ...typography.display },
  description: { color: colors.secondaryText, ...typography.body },
  form: { gap: spacing.md },
});
