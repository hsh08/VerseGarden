import { Pressable, StyleSheet, Text, View } from "react-native";

import type { BibleVerse } from "./bibleTypes";
import { createVerseReference } from "./bibleTypes";
import { colors, radius, spacing, typography } from "@/theme/tokens";

type VerseRowProps = {
  verse: BibleVerse;
  onPress: (verse: BibleVerse) => void;
};

export function VerseRow({ verse, onPress }: VerseRowProps) {
  const reference = createVerseReference(verse);
  return (
    <Pressable
      accessibilityHint="말씀 상세를 엽니다"
      accessibilityLabel={`${reference}, ${verse.text}`}
      accessibilityRole="button"
      onPress={() => onPress(verse)}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <View style={styles.referenceBadge}><Text style={styles.reference}>{reference}</Text></View>
      <Text numberOfLines={3} style={styles.text}>{verse.text}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.medium, borderWidth: StyleSheet.hairlineWidth, gap: spacing.sm, minHeight: 72, padding: spacing.md },
  pressed: { opacity: 0.76 },
  referenceBadge: { alignSelf: "flex-start", backgroundColor: colors.cardTint, borderRadius: radius.small, paddingHorizontal: spacing.xs, paddingVertical: spacing.xxs },
  reference: { color: colors.forestGreen, ...typography.label },
  text: { color: colors.primaryText, ...typography.body },
});
