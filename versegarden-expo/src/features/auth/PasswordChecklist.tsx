import { StyleSheet, Text, View } from "react-native";

import type { PasswordValidationResult } from "./authValidation";
import { colors, radius, spacing, typography } from "@/theme/tokens";

const rows: [keyof Pick<PasswordValidationResult, "hasMinimumLength" | "containsLetter" | "containsNumber" | "containsSpecialCharacter" | "matchesConfirmation">, string][] = [["hasMinimumLength", "8자 이상"], ["containsLetter", "영문 포함"], ["containsNumber", "숫자 포함"], ["containsSpecialCharacter", "특수문자 포함"], ["matchesConfirmation", "비밀번호 일치"]];

export function PasswordChecklist({ validation }: { validation: PasswordValidationResult }) {
  return <View style={styles.container}><Text style={styles.title}>비밀번호 조건</Text><View style={styles.rows}>{rows.map(([key, label]) => <Text accessibilityLabel={`${label} ${validation[key] ? "충족" : "미충족"}`} key={key} style={[styles.row, validation[key] && styles.satisfied]}>{validation[key] ? "✓" : "○"} {label}</Text>)}</View></View>;
}

const styles = StyleSheet.create({
  container: { backgroundColor: colors.cardTint, borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, gap: spacing.xs, padding: spacing.sm },
  title: { color: colors.secondaryText, ...typography.caption },
  rows: { flexDirection: "row", flexWrap: "wrap", gap: spacing.xs },
  row: { color: colors.secondaryText, minWidth: "45%", ...typography.caption },
  satisfied: { color: colors.forestGreen },
});
