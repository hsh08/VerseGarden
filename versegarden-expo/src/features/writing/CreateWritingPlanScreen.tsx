import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGPrimaryButton } from "@/components/ui";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

import { buildPlanPreview } from "./writingPlanLogic";

export function CreateWritingPlanScreen() {
  const router = useRouter(); const { repository } = useBibleRepository(); const { createPlan } = usePersonalVerse(); const books = useMemo(() => repository?.getBooks() ?? [], [repository]); const [book, setBook] = useState("창세기"); const [startChapter, setStartChapter] = useState("1"); const [endChapter, setEndChapter] = useState("1"); const [days, setDays] = useState("7"); const [error, setError] = useState<string | null>(null); const [isSaving, setIsSaving] = useState(false);
  if (!repository) return <VGScreen><Text style={styles.muted}>성경을 준비하고 있어요.</Text></VGScreen>;
  const validBook = books.some((item) => item.name === book.trim());
  const save = async () => { setError(null); try { const preview = buildPlanPreview(repository, { book: book.trim(), startChapter: Number(startChapter), endChapter: Number(endChapter), startDate: new Date(), totalDays: Number(days) }); setIsSaving(true); await createPlan(preview); router.back(); } catch (nextError) { const code = nextError instanceof Error ? nextError.message : ""; setError(code.includes("invalid-chapter") ? "시작 장과 끝 장을 확인해주세요." : code.includes("invalid-duration") ? "기간은 전체 구절 수보다 길 수 없어요." : "플랜을 만들지 못했습니다."); } finally { setIsSaving(false); } };
  return <VGScreen><Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.back}><Text style={styles.backLabel}>‹ 플랜</Text></Pressable><View style={styles.header}><Text style={styles.title}>필사 플랜 만들기</Text><Text style={styles.subtitle}>한 권의 장 범위와 기간을 정하면 하루 분량으로 나눠드려요.</Text></View><VGCard style={styles.form}><Text style={styles.label}>성경 책</Text><TextInput accessibilityLabel="성경 책" onChangeText={setBook} placeholder="예: 창세기" placeholderTextColor={colors.subtleText} style={styles.input} value={book} />{!validBook && book.trim() ? <Text style={styles.error}>성경 책 이름을 확인해주세요.</Text> : null}<View style={styles.row}><Field label="시작 장" value={startChapter} onChange={setStartChapter} /><Field label="끝 장" value={endChapter} onChange={setEndChapter} /></View><Field label="기간 (일)" value={days} onChange={setDays} />{error ? <Text accessibilityRole="alert" style={styles.error}>{error}</Text> : null}<VGPrimaryButton disabled={!validBook || isSaving} label={isSaving ? "만드는 중..." : "플랜 만들기"} onPress={() => void save()} /></VGCard></VGScreen>;
}
function Field({ label, onChange, value }: { label: string; value: string; onChange: (value: string) => void }) { return <View style={styles.field}><Text style={styles.label}>{label}</Text><TextInput accessibilityLabel={label} keyboardType="number-pad" onChangeText={onChange} style={styles.input} value={value} /></View>; }
const styles = StyleSheet.create({ back: { alignSelf: "flex-start", minHeight: 44, justifyContent: "center" }, backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, header: { gap: spacing.xxs }, title: { color: colors.primaryText, ...typography.title }, subtitle: { color: colors.secondaryText, ...typography.body }, form: { gap: spacing.sm }, row: { flexDirection: "row", gap: spacing.sm }, field: { flex: 1, gap: spacing.xxs }, label: { color: colors.primaryText, ...typography.label }, input: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 48, paddingHorizontal: spacing.md, ...typography.body }, error: { color: colors.destructive, ...typography.caption }, muted: { color: colors.secondaryText, ...typography.body } });
