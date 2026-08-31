import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView } from "@/components/ui";
import { createVerseReference } from "./bibleTypes";
import { useBibleRepository } from "./useBibleRepository";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export function VerseDetailScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ verseId?: string | string[] }>();
  const verseID = typeof params.verseId === "string" ? params.verseId : null;
  const { repository, error } = useBibleRepository();
  const { isLiked, toggleLike } = usePersonalVerse();

  if (!repository && !error) return <VGScreen><View style={styles.loading}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.loadingText}>말씀을 준비하고 있어요.</Text></View></VGScreen>;
  const verse = repository && verseID ? repository.getVerse(verseID) : null;
  if (!verse) return <VGScreen><VGEmptyStateView description={error ? "성경 데이터를 준비하지 못했습니다. 앱을 다시 시작한 뒤 시도해주세요." : "요청한 말씀을 찾지 못했습니다."} title={error ? "말씀을 불러올 수 없어요" : "말씀을 찾을 수 없어요"} /><Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.backButton}><Text style={styles.backLabel}>말씀 목록으로 돌아가기</Text></Pressable></VGScreen>;

  return (
    <VGScreen>
      <Pressable accessibilityRole="button" onPress={() => router.back()} style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}><Text style={styles.backLabel}>‹ 말씀 목록</Text></Pressable>
      <VGCard style={styles.verseCard}>
        <Text style={styles.reference}>{createVerseReference(verse)}</Text>
        <View style={styles.divider} />
        <Text selectable style={styles.verseText}>{verse.text}</Text>
        <Text style={styles.translation}>성경전서 개역한글</Text>
      </VGCard>
      <View style={styles.actions}>
        <Pressable accessibilityLabel={isLiked(verse.id) ? "저장한 말씀에서 제거" : "말씀 저장"} accessibilityRole="button" onPress={() => void toggleLike(verse.id)} style={({ pressed }) => [styles.action, pressed && styles.pressed]}><Text style={styles.actionText}>{isLiked(verse.id) ? "♥ 저장됨" : "♡ 말씀 저장"}</Text></Pressable>
        <Pressable accessibilityRole="button" onPress={() => router.push({ pathname: "/write/[verseId]", params: { verseId: verse.id } })} style={({ pressed }) => [styles.action, pressed && styles.pressed]}><Text style={styles.actionText}>필사하기</Text></Pressable>
        <Pressable accessibilityRole="button" onPress={() => router.push({ pathname: "/verse/lists", params: { addVerseId: verse.id } })} style={({ pressed }) => [styles.action, pressed && styles.pressed]}><Text style={styles.actionText}>리스트에 추가</Text></Pressable>
      </View>
    </VGScreen>
  );
}

const styles = StyleSheet.create({
  loading: { alignItems: "center", flex: 1, gap: spacing.sm, justifyContent: "center" },
  loadingText: { color: colors.secondaryText, ...typography.body },
  backButton: { alignSelf: "flex-start", justifyContent: "center", minHeight: 44, paddingHorizontal: spacing.xs },
  backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis },
  verseCard: { gap: spacing.lg },
  actions: { gap: spacing.sm },
  action: { alignItems: "center", backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, justifyContent: "center", minHeight: 52, paddingHorizontal: spacing.lg },
  actionText: { color: colors.forestGreen, ...typography.bodyEmphasis },
  reference: { alignSelf: "flex-start", backgroundColor: colors.cardTint, borderRadius: radius.small, color: colors.forestGreen, paddingHorizontal: spacing.sm, paddingVertical: spacing.xxs, ...typography.label },
  divider: { backgroundColor: colors.border, height: StyleSheet.hairlineWidth, width: 48 },
  verseText: { color: colors.primaryText, fontSize: 24, fontWeight: "400", lineHeight: 38 },
  translation: { color: colors.secondaryText, ...typography.caption },
  pressed: { opacity: 0.72 },
});
