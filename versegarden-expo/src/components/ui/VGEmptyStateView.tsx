import { StyleSheet, Text, View } from "react-native";

import { colors, spacing, typography } from "@/theme/tokens";

type VGEmptyStateViewProps = { title: string; description: string };

export function VGEmptyStateView({ title, description }: VGEmptyStateViewProps) {
  return <View accessibilityRole="summary" style={styles.container}><Text style={styles.title}>{title}</Text><Text style={styles.description}>{description}</Text></View>;
}

const styles = StyleSheet.create({
  container: { alignItems: "center", gap: spacing.xs, paddingVertical: spacing.lg },
  title: { color: colors.primaryText, textAlign: "center", ...typography.bodyEmphasis },
  description: { color: colors.secondaryText, textAlign: "center", ...typography.caption },
});
