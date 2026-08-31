import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView } from "@/components/ui";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { assignmentVerses, nextIncompleteAssignment, todayAssignment } from "@/features/writing/writingPlanLogic";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { useGarden } from "@/providers/GardenProvider";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { useQuietPrayer } from "@/providers/QuietPrayerProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export default function HomeTab() {
  const { profile } = useAuthSession();
  const router = useRouter();
  const { repository } = useBibleRepository();
  const { plans, assignmentsByPlan } = usePersonalVerse();
  const { qtRecord } = useQuietPrayer();
  const { stats: gardenStats } = useGarden();
  const name = profile?.nickname || profile?.email || "";
  const selected = plans.find((plan) => plan.localId === profile?.selectedWritingPlanId) ?? plans.find((plan) => plan.status === "active") ?? null;
  const assignments = selected ? assignmentsByPlan[selected.id] ?? [] : [];
  const today = selected ? todayAssignment(selected, assignments) : null;
  const next = selected ? (today && today.state !== "completed" ? today : nextIncompleteAssignment(selected, assignments)) : null;
  const isTodayWritingComplete = today?.state === "completed" || selected?.status === "completed";
  const todayQT = qtRecord();
  const openWriting = () => {
    if (!repository || !selected || !next) return;
    const verses = assignmentVerses(repository, next);
    const index = Math.min(next.completionRecordIds.length, Math.max(verses.length - 1, 0));
    if (!verses[index]) return;
    router.push({ pathname: "/write/[verseId]", params: { verseId: verses[index].id, planId: selected.id, assignmentId: next.id, index: String(index) } });
  };

  return <VGScreen>
    <View style={styles.header}><Text style={styles.brand}>VerseGarden</Text><Text style={styles.title}>{name ? `${name}님, 오늘도 말씀과 가까워지는 하루` : "오늘도 말씀과 가까워지는 하루"}</Text><Text style={styles.subtitle}>기록은 쌓이고, 믿음은 자랍니다.</Text></View>
    <VGCard tinted style={styles.gardenCard}><Text style={styles.eyebrow}>Garden 요약</Text><Text style={styles.planTitle}>{gardenStats.currentStreak}일 연속 기록</Text><Text style={styles.planRange}>{gardenStats.today.hasGrowthActivity ? `오늘 ${gardenStats.today.totalGrowthActivityCount}개의 성장 기록을 남겼어요.` : "오늘의 말씀, 기도, QT 기록을 정원에 심어보세요."}</Text><Pressable accessibilityRole="button" onPress={() => router.push("/(tabs)/garden" as never)} style={({ pressed }) => [styles.detailCta, pressed && styles.pressed]}><Text style={styles.detailCtaLabel}>Garden 보기</Text></Pressable></VGCard>
    {todayQT?.completedAt ? <VGCard tinted style={styles.qtCard}><Text style={styles.eyebrow}>오늘의 QT</Text><Text style={styles.planTitle}>오늘의 QT 완료</Text><Text style={styles.planRange}>오늘 남긴 기록을 다시 확인할 수 있어요.</Text><Pressable accessibilityRole="button" onPress={() => router.push("/qt" as never)} style={({ pressed }) => [styles.detailCta, pressed && styles.pressed]}><Text style={styles.detailCtaLabel}>QT 기록 보기</Text></Pressable></VGCard> : <VGCard tinted style={styles.qtCard}><Text style={styles.eyebrow}>오늘의 QT</Text><Text style={styles.planTitle}>{todayQT ? "오늘의 QT 이어하기" : "오늘의 QT 시작하기"}</Text><Text style={styles.planRange}>말씀을 읽고 묵상과 기도를 남겨보세요.</Text><Pressable accessibilityRole="button" onPress={() => router.push("/qt" as never)} style={({ pressed }) => [styles.cta, pressed && styles.pressed]}><Text style={styles.ctaLabel}>{todayQT ? "QT 이어하기" : "QT 시작하기"}</Text></Pressable></VGCard>}
    {selected && isTodayWritingComplete ? <VGCard tinted style={styles.planCard}><Text style={styles.eyebrow}>오늘의 필사</Text><Text style={styles.planTitle}>오늘 필사 완료</Text><Text style={styles.planRange}>완료 기록은 플랜 상세에서 확인할 수 있어요.</Text><Pressable accessibilityRole="button" onPress={() => router.push({ pathname: "/verse/plans/[planId]", params: { planId: selected.id } })} style={({ pressed }) => [styles.detailCta, pressed && styles.pressed]}><Text style={styles.detailCtaLabel}>플랜 상세 보기</Text></Pressable></VGCard> : selected && next ? <VGCard tinted style={styles.planCard}><Text style={styles.eyebrow}>{today?.id === next.id ? "오늘의 필사" : "다음 필사"}</Text><Text style={styles.planTitle}>{selected.title}</Text><Text style={styles.planRange}>{next.book} {next.startChapter}:{next.startVerse}–{next.endChapter}:{next.endVerse}</Text><Pressable accessibilityRole="button" onPress={openWriting} style={({ pressed }) => [styles.cta, pressed && styles.pressed]}><Text style={styles.ctaLabel}>필사 이어가기</Text></Pressable></VGCard> : <VGCard><VGEmptyStateView description="말씀 탭에서 필사 플랜을 만들면 오늘의 분량을 여기에서 이어갈 수 있어요." title="오늘의 필사 플랜이 없어요" /></VGCard>}
  </VGScreen>;
}

const styles = StyleSheet.create({
  header: { gap: spacing.xs, paddingTop: spacing.sm }, brand: { color: colors.forestGreen, ...typography.label }, title: { color: colors.primaryText, ...typography.display }, subtitle: { color: colors.secondaryText, ...typography.body },
  gardenCard: { gap: spacing.sm }, planCard: { gap: spacing.sm }, qtCard: { gap: spacing.sm }, eyebrow: { color: colors.forestGreen, ...typography.label }, planTitle: { color: colors.primaryText, ...typography.heading }, planRange: { color: colors.secondaryText, ...typography.body },
  cta: { alignItems: "center", backgroundColor: colors.forestGreen, borderRadius: radius.medium, justifyContent: "center", minHeight: 50, marginTop: spacing.xs }, ctaLabel: { color: colors.cardBackground, ...typography.bodyEmphasis }, detailCta: { alignItems: "center", borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, justifyContent: "center", minHeight: 50, marginTop: spacing.xs }, detailCtaLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, pressed: { opacity: 0.72 },
});
