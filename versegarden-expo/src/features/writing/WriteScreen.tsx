import { useMemo, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGPrimaryButton } from "@/components/ui";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

import { assignmentVerses } from "./writingPlanLogic";

export function WriteScreen() {
  const router = useRouter(); const params = useLocalSearchParams<{ verseId?: string; planId?: string; assignmentId?: string; index?: string }>(); const { repository } = useBibleRepository(); const { plans, assignmentsByPlan, saveFreeWriting, savePlanWriting } = usePersonalVerse(); const [userText, setUserText] = useState(""); const [isSaving, setIsSaving] = useState(false);
  const plan = typeof params.planId === "string" ? plans.find((item) => item.id === params.planId) : null; const assignment = plan && typeof params.assignmentId === "string" ? (assignmentsByPlan[plan.id] ?? []).find((item) => item.id === params.assignmentId) : null; const initialIndex = Math.max(Number(params.index ?? 0) || 0, 0); const planVerses = repository && assignment ? assignmentVerses(repository, assignment) : []; const verse = plan ? planVerses[initialIndex] ?? null : (repository && typeof params.verseId === "string" ? repository.getVerse(params.verseId) : null); const complete = Boolean(verse && userText === verse.text);
  if (!repository) return <VGScreen><View style={styles.loading}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.muted}>말씀을 준비하고 있어요.</Text></View></VGScreen>;
  if (!verse) return <VGScreen><Text style={styles.error}>필사할 말씀을 찾을 수 없어요.</Text><Pressable onPress={() => router.back()} style={styles.back}><Text style={styles.backLabel}>돌아가기</Text></Pressable></VGScreen>;
  const save = async () => { if (!complete || isSaving) return; setIsSaving(true); try { if (plan && assignment) { const last = initialIndex === planVerses.length - 1; await savePlanWriting(verse, userText, plan, assignment, last); if (!last) { router.replace({ pathname: "/write/[verseId]", params: { verseId: planVerses[initialIndex + 1].id, planId: plan.id, assignmentId: assignment.id, index: String(initialIndex + 1) } }); setUserText(""); } else router.back(); } else { await saveFreeWriting(verse, userText); router.back(); } } finally { setIsSaving(false); } };
  return <VGScreen><Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.back}><Text style={styles.backLabel}>‹ 돌아가기</Text></Pressable><VGCard style={styles.verseCard}><Text style={styles.reference}>{verse.book} {verse.chapter}:{verse.verse}</Text><Text style={styles.verseText}>{verse.text}</Text>{plan && assignment ? <Text style={styles.progress}>플랜 Day {assignment.dayIndex} · {initialIndex + 1}/{planVerses.length}절</Text> : null}</VGCard><VGCard style={styles.inputCard}><Text style={styles.inputTitle}>말씀 따라 쓰기</Text><Text style={styles.inputDescription}>회색 안내 글을 따라 한 글자씩 차분히 적어보세요.</Text><GuidedWritingInput inputText={userText} onChangeText={setUserText} targetText={verse.text} /><Text style={[styles.status, complete && styles.complete]}>{complete ? "필사가 완료되었습니다." : "같은 순서와 띄어쓰기로 입력하면 완료됩니다."}</Text><VGPrimaryButton disabled={!complete || isSaving} label={isSaving ? "저장 중..." : plan && initialIndex < planVerses.length - 1 ? "저장하고 다음 구절" : "필사 완료"} onPress={() => void save()} /></VGCard></VGScreen>;
}

function GuidedWritingInput({ inputText, onChangeText, targetText }: { inputText: string; onChangeText: (value: string) => void; targetText: string }) {
  const characters = useMemo<{ expected: string | null; typed: string | null }[]>(() => {
    const target = Array.from(targetText);
    const input = Array.from(inputText);
    return [...target.map((expected, index) => ({ expected, typed: input[index] ?? null })), ...input.slice(target.length).map((typed) => ({ expected: null, typed }))];
  }, [inputText, targetText]);

  return <View style={styles.guidedTextArea}>
    <Text accessible={false} pointerEvents="none" style={styles.guideText}>{characters.map((character, index) => <Text key={`${index}-${character.expected ?? "extra"}`} style={character.typed === null ? styles.guideRemaining : character.typed === character.expected ? styles.guideCorrect : styles.guideWrong}>{character.typed ?? character.expected}</Text>)}</Text>
    <TextInput accessibilityLabel="말씀 따라 쓰기" autoCapitalize="none" autoCorrect={false} cursorColor={colors.forestGreen} multiline onChangeText={onChangeText} selectionColor={colors.forestGreen} style={styles.textAreaInput} textAlignVertical="top" underlineColorAndroid="transparent" value={inputText} />
  </View>;
}

const styles = StyleSheet.create({ loading: { alignItems: "center", flex: 1, gap: spacing.sm, justifyContent: "center" }, muted: { color: colors.secondaryText, ...typography.body }, error: { color: colors.destructive, ...typography.body }, back: { alignSelf: "flex-start", minHeight: 44, justifyContent: "center" }, backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, verseCard: { gap: spacing.md }, reference: { color: colors.forestGreen, ...typography.label }, verseText: { color: colors.primaryText, fontSize: 22, lineHeight: 34 }, progress: { color: colors.secondaryText, ...typography.caption }, inputCard: { gap: spacing.md }, inputTitle: { color: colors.primaryText, ...typography.heading }, inputDescription: { color: colors.secondaryText, ...typography.caption }, guidedTextArea: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, minHeight: 180, overflow: "hidden", position: "relative" }, guideText: { color: colors.subtleText, minHeight: 180, padding: spacing.md, ...typography.body }, guideRemaining: { color: colors.subtleText }, guideCorrect: { color: colors.primaryText }, guideWrong: { backgroundColor: "#F2DEDA", color: colors.destructive }, textAreaInput: { bottom: 0, color: "transparent", left: 0, minHeight: 180, padding: spacing.md, position: "absolute", right: 0, top: 0, ...typography.body }, status: { color: colors.secondaryText, ...typography.caption }, complete: { color: colors.forestGreen, ...typography.label } });
