import { useState } from "react";
import { Pressable, StyleSheet, Text, TextInput, View, type TextInputProps } from "react-native";

import { colors, radius, spacing, typography } from "@/theme/tokens";

type AuthTextFieldProps = TextInputProps & { label: string; secure?: boolean };

export function AuthTextField({ label, secure = false, style, ...props }: AuthTextFieldProps) {
  const [secureVisible, setSecureVisible] = useState(false);
  return <View style={styles.container}><Text style={styles.label}>{label}</Text><View style={styles.field}><TextInput accessibilityLabel={label} autoCapitalize="none" autoCorrect={false} placeholderTextColor={colors.subtleText} secureTextEntry={secure && !secureVisible} style={[styles.input, style]} {...props} />{secure ? <Pressable accessibilityRole="button" accessibilityLabel={secureVisible ? "비밀번호 숨기기" : "비밀번호 보기"} hitSlop={8} onPress={() => setSecureVisible((visible) => !visible)}><Text style={styles.toggle}>{secureVisible ? "숨기기" : "보기"}</Text></Pressable> : null}</View></View>;
}

const styles = StyleSheet.create({
  container: { gap: spacing.xxs },
  label: { color: colors.primaryText, ...typography.label },
  field: { alignItems: "center", backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, flexDirection: "row", minHeight: 52, paddingLeft: spacing.sm, paddingRight: spacing.sm },
  input: { color: colors.primaryText, flex: 1, minHeight: 50, paddingVertical: spacing.xs, ...typography.body },
  toggle: { color: colors.forestGreen, padding: spacing.xxs, ...typography.caption },
});
