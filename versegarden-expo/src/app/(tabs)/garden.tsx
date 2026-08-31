import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView, VGSectionHeader } from "@/components/ui";
import { monthDateKeys } from "@/features/garden/gardenLogic";
import { gardenActivityLabels } from "@/features/garden/gardenTypes";
import { dateForKey, dateKeyFor } from "@/features/qt/qtTypes";
import { useGarden } from "@/providers/GardenProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

function monthLabel(month: Date): string {
  const [year, monthNumber] = dateKeyFor(month).split("-").map(Number);
  return `${year}년 ${monthNumber}월`;
}

function shiftMonth(value: Date, amount: number): Date {
  const [year, month] = dateKeyFor(value).split("-").map(Number);
  const next = new Date(Date.UTC(year, month - 1 + amount, 1));
  return dateForKey(`${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, "0")}-01`);
}

export default function GardenTab() {
  const { stats } = useGarden();
  const [displayedMonth, setDisplayedMonth] = useState(() => dateForKey(`${dateKeyFor().slice(0, 7)}-01`));
  const monthKeys = useMemo(() => monthDateKeys(displayedMonth), [displayedMonth]);
  const todayKey = dateKeyFor();
  const canMoveForward = dateKeyFor(shiftMonth(displayedMonth, 1)) <= `${todayKey.slice(0, 7)}-01`;
  const leadingBlankDays = useMemo(() => (dateForKey(monthKeys[0] ?? todayKey).getUTCDay() + 6) % 7, [monthKeys, todayKey]);
  const cells = [...Array.from({ length: leadingBlankDays }, () => null), ...monthKeys];

  return <VGScreen>
    <View style={styles.header}><Text style={styles.eyebrow}>나의 기록 정원</Text><Text style={styles.title}>Garden</Text><Text style={styles.subtitle}>쌓인 말씀과 기도가 오늘의 정원을 만듭니다.</Text></View>
    <View style={styles.statRow}>
      <VGCard tinted style={styles.statCard}><Text style={styles.statLabel}>현재 연속</Text><Text style={styles.statValue}>{stats.currentStreak}일</Text></VGCard>
      <VGCard tinted style={styles.statCard}><Text style={styles.statLabel}>전체 활동</Text><Text style={styles.statValue}>{stats.totalGrowthActivityCount}회</Text></VGCard>
    </View>
    <VGCard style={styles.heatmapCard}>
      <View style={styles.monthHeader}><Pressable accessibilityLabel="이전 달" accessibilityRole="button" hitSlop={8} onPress={() => setDisplayedMonth((value) => shiftMonth(value, -1))} style={styles.monthButton}><Text style={styles.monthButtonLabel}>{"<"}</Text></Pressable><Text style={styles.monthTitle}>{monthLabel(displayedMonth)}</Text><Pressable accessibilityLabel="다음 달" accessibilityRole="button" disabled={!canMoveForward} hitSlop={8} onPress={() => setDisplayedMonth((value) => shiftMonth(value, 1))} style={[styles.monthButton, !canMoveForward && styles.disabled]}><Text style={styles.monthButtonLabel}>{">"}</Text></Pressable></View>
      <View style={styles.weekdays}>{["월", "화", "수", "목", "금", "토", "일"].map((weekday) => <Text key={weekday} style={styles.weekday}>{weekday}</Text>)}</View>
      <View style={styles.grid}>{cells.map((dateKey, index) => dateKey ? <View key={dateKey} style={[styles.dayCell, stats.summariesByDateKey[dateKey]?.hasGrowthActivity && styles.activeDay, dateKey === todayKey && styles.todayDay]}><Text style={[styles.dayLabel, stats.summariesByDateKey[dateKey]?.hasGrowthActivity && styles.activeDayLabel]}>{dateKey.slice(-2).replace(/^0/, "")}</Text><Text style={[styles.dayCount, stats.summariesByDateKey[dateKey]?.hasGrowthActivity && styles.activeDayLabel]}>{stats.summariesByDateKey[dateKey]?.totalGrowthActivityCount ?? ""}</Text></View> : <View key={`blank-${index}`} style={styles.dayCell} />)}</View>
      <Text style={styles.legend}>색이 있는 날짜는 말씀 저장, 필사, 기도, QT 완료 기록이 있는 날입니다.</Text>
    </VGCard>
    <VGCard tinted style={styles.todayCard}><Text style={styles.todayTitle}>오늘의 기록</Text><Text style={styles.todayText}>{stats.today.hasGrowthActivity ? `말씀 저장 ${stats.today.verseLikedCount} · 필사 ${stats.today.scriptureCopyCount} · 기도 ${stats.today.prayerCount} · QT ${stats.today.qtCompletedCount}` : "오늘 남긴 성장 기록이 아직 없어요."}</Text></VGCard>
    <VGSectionHeader title="최근 활동" />
    {stats.recentActivities.length ? <View style={styles.recentList}>{stats.recentActivities.map((activity) => <VGCard key={activity.id} style={styles.activityCard}><View><Text style={styles.activityTitle}>{gardenActivityLabels[activity.type]}</Text><Text style={styles.activityMeta}>{activity.reference ?? dateKeyFor(activity.createdAt)}</Text></View><Text style={styles.activityDate}>{dateKeyFor(activity.createdAt)}</Text></VGCard>)}</View> : <VGCard><VGEmptyStateView title="아직 Garden 기록이 없어요" description="말씀을 저장하거나 필사, 기도, QT를 완료하면 이곳에 기록됩니다." /></VGCard>}
  </VGScreen>;
}

const styles = StyleSheet.create({
  header: { gap: spacing.xs }, eyebrow: { color: colors.forestGreen, ...typography.label }, title: { color: colors.primaryText, ...typography.display }, subtitle: { color: colors.secondaryText, ...typography.body },
  statRow: { flexDirection: "row", gap: spacing.sm }, statCard: { flex: 1, gap: spacing.xxs, padding: spacing.md }, statLabel: { color: colors.secondaryText, ...typography.caption }, statValue: { color: colors.primaryText, ...typography.heading },
  heatmapCard: { gap: spacing.md, padding: spacing.md }, monthHeader: { alignItems: "center", flexDirection: "row", justifyContent: "space-between" }, monthTitle: { color: colors.primaryText, ...typography.bodyEmphasis }, monthButton: { alignItems: "center", borderColor: colors.border, borderRadius: radius.small, borderWidth: StyleSheet.hairlineWidth, height: 36, justifyContent: "center", width: 36 }, monthButtonLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, disabled: { opacity: 0.35 },
  weekdays: { flexDirection: "row" }, weekday: { color: colors.secondaryText, flex: 1, textAlign: "center", ...typography.caption }, grid: { flexDirection: "row", flexWrap: "wrap", rowGap: spacing.xs }, dayCell: { alignItems: "center", borderRadius: radius.small, height: 46, justifyContent: "center", width: "14.2857%" }, activeDay: { backgroundColor: colors.sageGreen }, todayDay: { borderColor: colors.forestGreen, borderWidth: 1 }, dayLabel: { color: colors.secondaryText, ...typography.caption }, dayCount: { color: colors.secondaryText, fontSize: 11, lineHeight: 14 }, activeDayLabel: { color: colors.cardBackground, fontWeight: "700" }, legend: { color: colors.secondaryText, ...typography.caption },
  todayCard: { gap: spacing.xxs }, todayTitle: { color: colors.primaryText, ...typography.heading }, todayText: { color: colors.secondaryText, ...typography.body }, recentList: { gap: spacing.sm }, activityCard: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", padding: spacing.md }, activityTitle: { color: colors.primaryText, ...typography.bodyEmphasis }, activityMeta: { color: colors.secondaryText, ...typography.caption }, activityDate: { color: colors.subtleText, ...typography.caption },
});
