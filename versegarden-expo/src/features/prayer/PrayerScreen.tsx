import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";

import { VGCard, VGEmptyStateView, VGPrimaryButton } from "@/components/ui";
import { VGScreen } from "@/components/layout/VGScreen";
import { useQuietPrayer } from "@/providers/QuietPrayerProvider";
import { colors, spacing, typography } from "@/theme/tokens";

export function PrayerScreen() {
  const router = useRouter(); const { prayerRecords, deletePrayer, errorMessage } = useQuietPrayer();
  const remove = (id: string) => Alert.alert("기도 기록을 삭제할까요?", "기도 기록이 삭제됩니다.", [{ text: "취소", style: "cancel" }, { text: "삭제", style: "destructive", onPress: () => void deletePrayer(id).catch(() => undefined) }]);
  return <VGScreen><View style={styles.header}><Text style={styles.title}>기도</Text><Text style={styles.subtitle}>오늘의 마음을 기도로 기록해보세요.</Text></View><VGPrimaryButton label="새 기도 작성" onPress={() => router.push("/prayer-record/new" as never)} />{errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}{prayerRecords.length === 0 ? <VGEmptyStateView description="마음을 적어두면 기도 기록으로 모입니다." title="아직 기도 기록이 없어요" /> : <View style={styles.list}>{prayerRecords.map((record) => <VGCard key={record.id} style={styles.card}><Pressable accessibilityRole="button" onPress={() => router.push({ pathname: "/prayer-record/[recordId]" as never, params: { recordId: record.id } })} style={({ pressed }) => [styles.open, pressed && styles.pressed]}><Text style={styles.recordTitle}>{record.titleSnapshot}</Text><Text numberOfLines={2} style={styles.preview}>{record.userText}</Text><Text style={styles.date}>{record.completedAt.toLocaleDateString("ko-KR")}</Text></Pressable><Pressable accessibilityLabel={`${record.titleSnapshot} 삭제`} accessibilityRole="button" onPress={() => remove(record.id)} style={styles.delete}><Text style={styles.deleteLabel}>삭제</Text></Pressable></VGCard>)}</View>}</VGScreen>;
}
const styles = StyleSheet.create({ header: { gap: spacing.xxs }, title: { color: colors.primaryText, ...typography.title }, subtitle: { color: colors.secondaryText, ...typography.body }, list: { gap: spacing.sm }, card: { gap: spacing.xs }, open: { gap: spacing.xxs, minHeight: 64 }, recordTitle: { color: colors.primaryText, ...typography.heading }, preview: { color: colors.secondaryText, ...typography.body }, date: { color: colors.subtleText, ...typography.caption }, delete: { alignSelf: "flex-start", minHeight: 36, justifyContent: "center" }, deleteLabel: { color: colors.destructive, ...typography.label }, error: { color: colors.destructive, ...typography.caption }, pressed: { opacity: 0.72 } });
