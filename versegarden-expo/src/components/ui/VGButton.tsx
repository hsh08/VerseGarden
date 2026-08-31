import { Pressable, StyleSheet, Text, type PressableProps, type StyleProp, type ViewStyle } from "react-native";

import { colors, radius, spacing, typography } from "@/theme/tokens";

type VGButtonProps = Omit<PressableProps, "children" | "style"> & { label: string; style?: StyleProp<ViewStyle> };

export function VGPrimaryButton({ label, disabled = false, style, ...props }: VGButtonProps) {
  return <Button label={label} disabled={disabled} style={style} {...props} />;
}

export function VGSecondaryButton({ label, disabled = false, style, ...props }: VGButtonProps) {
  return <Button label={label} disabled={disabled} secondary style={style} {...props} />;
}

function Button({ label, disabled = false, secondary = false, style, ...props }: VGButtonProps & { secondary?: boolean }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: Boolean(disabled) }}
      disabled={disabled}
      style={({ pressed }) => [styles.button, secondary && styles.secondary, style, pressed && !disabled && styles.pressed, disabled && styles.disabled]}
      {...props}>
      <Text style={[styles.label, secondary && styles.secondaryLabel, disabled && styles.disabledLabel]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { alignItems: "center", backgroundColor: colors.forestGreen, borderRadius: radius.medium, justifyContent: "center", minHeight: 48, paddingHorizontal: spacing.lg, paddingVertical: spacing.sm },
  label: { color: colors.cardBackground, ...typography.bodyEmphasis },
  secondary: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderWidth: 1 },
  secondaryLabel: { color: colors.forestGreen },
  pressed: { opacity: 0.82 },
  disabled: { backgroundColor: colors.cardTint, borderColor: colors.border, opacity: 0.8 },
  disabledLabel: { color: colors.subtleText },
});
