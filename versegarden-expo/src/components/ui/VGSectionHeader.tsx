import { StyleSheet, Text, View } from "react-native";

import { colors, spacing, typography } from "@/theme/tokens";

type VGSectionHeaderProps = { title: string; description?: string };

export function VGSectionHeader({ title, description }: VGSectionHeaderProps) {
  return <View style={styles.container}><Text style={styles.title}>{title}</Text>{description ? <Text style={styles.description}>{description}</Text> : null}</View>;
}

const styles = StyleSheet.create({
  container: { gap: spacing.xxs },
  title: { color: colors.primaryText, ...typography.heading },
  description: { color: colors.secondaryText, ...typography.body },
});
