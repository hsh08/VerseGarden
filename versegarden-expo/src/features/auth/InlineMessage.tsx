import { StyleSheet, Text } from "react-native";

import { colors, radius, spacing, typography } from "@/theme/tokens";

export function InlineMessage({ message, success = false }: { message: string; success?: boolean }) {
  return <Text accessibilityRole="alert" style={[styles.message, success ? styles.success : styles.error]}>{message}</Text>;
}

const styles = StyleSheet.create({
  message: { borderRadius: radius.small, paddingHorizontal: spacing.sm, paddingVertical: spacing.xs, ...typography.caption },
  error: { backgroundColor: colors.destructiveSurface, color: colors.destructive },
  success: { backgroundColor: colors.cardTint, color: colors.forestGreen },
});
