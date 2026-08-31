import type { PropsWithChildren } from "react";
import { ScrollView, StyleSheet, View, type ScrollViewProps } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { colors, spacing } from "@/theme/tokens";

type VGScreenProps = PropsWithChildren<ScrollViewProps> & { scrollable?: boolean };

export function VGScreen({ children, scrollable = true, contentContainerStyle, style, ...props }: VGScreenProps) {
  const content = <View style={[styles.content, contentContainerStyle]}>{children}</View>;
  return <SafeAreaView edges={["top", "left", "right"]} style={styles.safeArea}>{scrollable ? <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled" style={style} {...props}>{content}</ScrollView> : content}</SafeAreaView>;
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: colors.background },
  scrollContent: { flexGrow: 1 },
  content: { flex: 1, gap: spacing.lg, paddingHorizontal: spacing.screen, paddingTop: spacing.lg, paddingBottom: spacing.lg },
});
