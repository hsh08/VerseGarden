import { useEffect, useState } from "react";
import { ActivityIndicator, Alert, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";

import { VGCard, VGPrimaryButton } from "@/components/ui";
import { VGScreen } from "@/components/layout/VGScreen";
import { useQuietPrayer } from "@/providers/QuietPrayerProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export function PrayerComposerScreen() {
  const router = useRouter(); const { recordId } = useLocalSearchParams<{ recordId?: string }>(); const { prayerRecords, createPrayer, updatePrayer, deletePrayer, errorMessage } = useQuietPrayer(); const record = typeof recordId === "string" && recordId !== "new" ? prayerRecords.find((item) => item.id === recordId) : null; const [title, setTitle] = useState(""); const [userText, setUserText] = useState(""); const [isSaving, setIsSaving] = useState(false);
  useEffect(() => {
    const hydrate = setTimeout(() => { setTitle(record?.titleSnapshot ?? ""); setUserText(record?.userText ?? ""); }, 0);
    return () => clearTimeout(hydrate);
  }, [record?.id, record?.titleSnapshot, record?.userText]);
  const valid = title.trim().length >= 2 && userText.trim().length >= 2;
  const save = async () => { if (!valid || isSaving) return; setIsSaving(true); try { if (record) await updatePrayer(record.id, title.trim(), userText.trim()); else await createPrayer(title.trim(), userText.trim()); router.back(); } finally { setIsSaving(false); } };
  const remove = () => { if (!record) return; Alert.alert("기도 기록을 삭제할까요?", "기도 기록이 삭제됩니다.", [{ text: "취소", style: "cancel" }, { text: "삭제", style: "destructive", onPress: () => void deletePrayer(record.id).then(() => router.back()).catch(() => undefined) }]); };
  if (typeof recordId === "string" && recordId !== "new" && !record) return <VGScreen><View style={styles.loading}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.muted}>기도 기록을 불러오고 있어요.</Text></View></VGScreen>;
  return <VGScreen><Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.back}><Text style={styles.backLabel}>‹ 기도</Text></Pressable><View style={styles.header}><Text style={styles.title}>{record ? "기도 기록 수정" : "새 기도 작성"}</Text><Text style={styles.muted}>자유롭게 기도 제목과 내용을 남겨보세요.</Text></View><VGCard style={styles.card}><Text style={styles.label}>기도 제목</Text><TextInput accessibilityLabel="기도 제목" onChangeText={setTitle} placeholder="오늘의 기도 제목" placeholderTextColor={colors.subtleText} style={styles.titleInput} value={title} /><Text style={styles.label}>직접 기록</Text><TextInput accessibilityLabel="직접 기록" multiline onChangeText={setUserText} placeholder="기도를 적어보세요" placeholderTextColor={colors.subtleText} style={styles.textArea} textAlignVertical="top" value={userText} /></VGCard>{errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}<VGPrimaryButton disabled={!valid || isSaving} label={isSaving ? "저장 중..." : record ? "수정 완료" : "기도 저장"} onPress={() => void save()} />{record ? <Pressable accessibilityRole="button" onPress={remove} style={styles.delete}><Text style={styles.deleteLabel}>기록 삭제</Text></Pressable> : null}</VGScreen>;
}
const styles = StyleSheet.create({ loading: { alignItems: "center", flex: 1, gap: spacing.sm, justifyContent: "center" }, back: { alignSelf: "flex-start", minHeight: 44, justifyContent: "center" }, backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, header: { gap: spacing.xxs }, title: { color: colors.primaryText, ...typography.title }, muted: { color: colors.secondaryText, ...typography.body }, card: { gap: spacing.sm }, label: { color: colors.primaryText, ...typography.bodyEmphasis }, titleInput: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 48, paddingHorizontal: spacing.md, ...typography.body }, textArea: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 220, padding: spacing.md, ...typography.body }, delete: { alignItems: "center", justifyContent: "center", minHeight: 48 }, deleteLabel: { color: colors.destructive, ...typography.bodyEmphasis }, error: { color: colors.destructive, ...typography.caption } });
