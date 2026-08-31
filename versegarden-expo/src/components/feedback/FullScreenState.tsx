import { ActivityIndicator, StyleSheet, Text, View } from "react-native";

import { VGPrimaryButton } from "@/components/ui";
import { colors, spacing, typography } from "@/theme/tokens";

type FullScreenStateProps = { title: string; description?: string; loading?: boolean; actionLabel?: string; onAction?: () => void };

export function FullScreenState({ title, description, loading = false, actionLabel, onAction }: FullScreenStateProps) {
  return <View style={styles.container}>{loading ? <ActivityIndicator color={colors.forestGreen} size="large" /> : null}<Text style={styles.title}>{title}</Text>{description ? <Text style={styles.description}>{description}</Text> : null}{actionLabel && onAction ? <VGPrimaryButton label={actionLabel} onPress={onAction} style={styles.action} /> : null}</View>;
}

const styles = StyleSheet.create({
  container: { alignItems: "center", backgroundColor: colors.background, flex: 1, gap: spacing.sm, justifyContent: "center", paddingHorizontal: spacing.screen },
  title: { color: colors.primaryText, textAlign: "center", ...typography.heading },
  description: { color: colors.secondaryText, textAlign: "center", ...typography.body },
  action: { alignSelf: "stretch", marginTop: spacing.sm },
});
