import { useContext } from "react";
import { StyleSheet, Text, View } from "react-native";

import { AppBootstrapContext } from "@/providers/AppProviders";
import { colors, spacing, typography } from "@/theme/tokens";

export function AppBootstrapNotice() {
  const { error } = useContext(AppBootstrapContext);
  if (!__DEV__ || !error) return null;

  return (
    <View accessibilityRole="alert" style={styles.banner}>
      <Text style={styles.title}>Development initialization issue</Text>
      <Text style={styles.message}>{error.message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: { backgroundColor: colors.destructiveSurface, borderColor: colors.destructive, borderWidth: StyleSheet.hairlineWidth, gap: spacing.xxs, marginHorizontal: spacing.screen, marginBottom: spacing.sm, padding: spacing.sm },
  title: { color: colors.destructive, ...typography.label },
  message: { color: colors.primaryText, ...typography.caption },
});
