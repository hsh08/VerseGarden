import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGEmptyStateView, VGPrimaryButton } from "@/components/ui";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

import { progressForPlan } from "./writingPlanLogic";

export function WritingPlansScreen() {
  const router = useRouter(); const { plans, assignmentsByPlan } = usePersonalVerse(); const { profile, selectWritingPlan } = useAuthSession();
  return <VGScreen><View style={styles.header}><Text style={styles.title}>필사 플랜</Text><Text style={styles.subtitle}>매일의 말씀 분량을 차분히 이어가 보세요.</Text></View><VGPrimaryButton label="새 플랜 만들기" onPress={() => router.push("/verse/plans/new")} />{plans.length === 0 ? <VGEmptyStateView description="책과 기간을 정하면 하루 분량을 나눠드려요." title="아직 필사 플랜이 없어요" /> : <View style={styles.list}>{plans.map((plan) => { const progress = progressForPlan(plan, assignmentsByPlan[plan.id] ?? []); const selected = profile?.selectedWritingPlanId === plan.localId; return <View key={plan.id} style={styles.card}><Pressable accessibilityLabel={`${plan.title} 플랜 열기`} accessibilityRole="button" onPress={() => router.push({ pathname: "/verse/plans/[planId]", params: { planId: plan.id } })} style={({ pressed }) => [styles.planOpen, pressed && styles.pressed]}><Text style={styles.planTitle}>{plan.title}</Text><Text style={styles.planRange}>{plan.book} {plan.startChapter}–{plan.endChapter}장</Text><Text style={styles.planProgress}>{plan.status === "completed" ? "완료" : `${progress.completed}/${progress.total}일 완료`}</Text></Pressable><Pressable accessibilityRole="button" accessibilityLabel={`${plan.title} ${selected ? "홈 표시 해제" : "홈에 표시"}`} onPress={() => void selectWritingPlan(selected ? null : plan.localId)} style={({ pressed }) => [styles.select, pressed && styles.pressed]}><Text style={styles.selectLabel}>{selected ? "홈에 표시 중" : "홈에 표시"}</Text></Pressable></View>; })}</View>}</VGScreen>;
}
const styles = StyleSheet.create({ header: { gap: spacing.xxs }, title: { color: colors.primaryText, ...typography.title }, subtitle: { color: colors.secondaryText, ...typography.body }, list: { gap: spacing.sm }, card: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.large, borderWidth: 1, padding: spacing.lg }, planOpen: { gap: spacing.xxs, minHeight: 76 }, planTitle: { color: colors.primaryText, ...typography.heading }, planRange: { color: colors.secondaryText, ...typography.body }, planProgress: { color: colors.forestGreen, ...typography.label }, select: { alignSelf: "flex-start", marginTop: spacing.xs, minHeight: 40, justifyContent: "center" }, selectLabel: { color: colors.forestGreen, ...typography.label }, pressed: { opacity: 0.72 } });
