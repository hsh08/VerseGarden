import type { PropsWithChildren } from "react";
import { StyleSheet, View, type ViewProps } from "react-native";

import { colors, radius, shadows, spacing } from "@/theme/tokens";

type VGCardProps = PropsWithChildren<ViewProps> & { tinted?: boolean };

export function VGCard({ children, tinted = false, style, ...props }: VGCardProps) {
  return <View style={[styles.card, tinted && styles.tinted, style]} {...props}>{children}</View>;
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.large, borderWidth: StyleSheet.hairlineWidth, padding: spacing.lg, ...shadows.card },
  tinted: { backgroundColor: colors.cardTint },
});
