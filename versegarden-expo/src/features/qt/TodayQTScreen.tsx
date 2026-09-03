import { useEffect, useState } from "react";
import { ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";

import { VGCard, VGPrimaryButton } from "@/components/ui";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { dateKeyFor, isQTComplete, type QTContent } from "@/features/qt/qtTypes";
import { qtRepository } from "@/features/qt/qtRepository";
import { useQuietPrayer } from "@/providers/QuietPrayerProvider";
import { useCommunity } from "@/providers/CommunityProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export function TodayQTScreen() {
  const router = useRouter(); const { repository } = useBibleRepository(); const { qtRecord, saveQTDraft, completeQT, errorMessage } = useQuietPrayer(); const { selectedCommunity } = useCommunity();
  const [content, setContent] = useState<QTContent | null>(null); const [reflectionAnswer, setReflectionAnswer] = useState(""); const [applicationText, setApplicationText] = useState(""); const [prayerText, setPrayerText] = useState(""); const [isCompleting, setIsCompleting] = useState(false); const [didLoadRecord, setDidLoadRecord] = useState(false);
  const dateKey = dateKeyFor(new Date(), selectedCommunity?.timezone); const existing = qtRecord(content?.dateKey ?? dateKey); const completed = isQTComplete(existing); const canComplete = [reflectionAnswer, applicationText, prayerText].some((value) => value.trim().length > 0);

  useEffect(() => {
    if (!repository) return;
    let active = true;
    void qtRepository.resolveToday(repository, new Date(), selectedCommunity).then((next) => { if (active) setContent(next); }).catch(() => { if (active) setContent(null); });
    return () => { active = false; };
  }, [repository, selectedCommunity]);

  useEffect(() => {
    if (!content || didLoadRecord) return;
    const hydrate = setTimeout(() => { setReflectionAnswer(existing?.reflectionAnswer ?? ""); setApplicationText(existing?.applicationText ?? ""); setPrayerText(existing?.prayerText ?? ""); setDidLoadRecord(true); }, 0);
    return () => clearTimeout(hydrate);
  }, [content, didLoadRecord, existing?.applicationText, existing?.id, existing?.prayerText, existing?.reflectionAnswer]);

  useEffect(() => {
    if (!content || !didLoadRecord || completed || !canComplete) return;
    const timer = setTimeout(() => { void saveQTDraft(content, { reflectionAnswer, applicationText, prayerText }).catch(() => undefined); }, 700);
    return () => clearTimeout(timer);
  }, [applicationText, canComplete, completed, content, didLoadRecord, prayerText, reflectionAnswer, saveQTDraft]);

  const complete = async () => {
    if (!content || !canComplete || completed || isCompleting) return;
    if (__DEV__) console.info("[QT Complete] pressed", { source: content.source });
    setIsCompleting(true);
    try {
      if (__DEV__) console.info("[QT Complete] validation passed", { source: content.source });
      await completeQT(content, { reflectionAnswer, applicationText, prayerText });
      if (__DEV__) console.info("[QT Complete] dismiss requested", { destination: "home" });
      router.back();
    } catch {
      if (__DEV__) console.info("[QT Complete] personal save failed");
    } finally {
      setIsCompleting(false);
    }
  };
  if (!content) return <SafeAreaView style={styles.safe}><View style={styles.loading}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.muted}>오늘의 QT를 준비하고 있어요.</Text></View></SafeAreaView>;

  const communityQT = content.source === "community";
  return <SafeAreaView style={styles.safe}><KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.flex}><ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled"><Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.back}><Text style={styles.backLabel}>‹ 홈</Text></Pressable><View style={styles.header}><Text style={styles.eyebrow}>{communityQT ? `공동체 QT · ${content.communityName ?? ""}` : content.source === "global" ? "오늘의 QT" : "말씀으로 시작하는 QT"}</Text><Text style={styles.title}>{content.title}</Text><Text style={styles.date}>{content.dateKey}</Text></View><VGCard style={styles.card}><Text style={styles.sectionTitle}>{content.reference}</Text>{content.verseLines.map((verse) => <Text key={verse.id} style={styles.verseText}>{verse.verse}. {verse.text}</Text>)}</VGCard>{communityQT ? <VGCard tinted style={styles.disclosure}><Text style={styles.sectionTitle}>공동체 QT입니다</Text><Text style={styles.muted}>작성한 묵상과 적용 답변은 공동체 리더와 관리자에게 공유됩니다. 기도 내용은 나에게만 저장됩니다.</Text></VGCard> : null}<QTInputCard label="말씀을 묵상해요" shared={communityQT} prompt={content.reflectionPrompt} value={reflectionAnswer} onChangeText={setReflectionAnswer} placeholder="여기에 묵상을 적어보세요" /><QTInputCard label="오늘 나에게" shared={communityQT} prompt={content.applicationPrompt} value={applicationText} onChangeText={setApplicationText} placeholder="오늘의 적용을 적어보세요" /><QTInputCard label="기도로 마무리해요" privateOnly={communityQT} prompt={content.prayerPrompt} value={prayerText} onChangeText={setPrayerText} placeholder="기도를 적어보세요" />{errorMessage ? <Text style={styles.error}>{errorMessage}</Text> : null}<VGCard style={styles.card}><Text style={styles.sectionTitle}>오늘의 아멘</Text><Text style={styles.muted}>묵상, 적용, 기도 중 하나 이상을 남기면 완료할 수 있어요.</Text><VGPrimaryButton disabled={!canComplete || completed || isCompleting} label={completed ? "오늘의 QT 완료" : isCompleting ? "완료 중..." : "QT 완료"} onPress={() => void complete()} /></VGCard></ScrollView></KeyboardAvoidingView></SafeAreaView>;
}

function QTInputCard({ label, prompt, value, onChangeText, placeholder, shared, privateOnly }: { label: string; prompt: string; value: string; onChangeText: (value: string) => void; placeholder: string; shared?: boolean; privateOnly?: boolean }) {
  return <VGCard style={styles.card}><Text style={styles.sectionTitle}>{label}</Text>{shared ? <Text style={styles.shared}>공동체에 공유됨</Text> : null}{privateOnly ? <Text style={styles.private}>나만 볼 수 있음</Text> : null}<Text style={styles.prompt}>{prompt}</Text><TextInput accessibilityLabel={label} multiline onChangeText={onChangeText} placeholder={placeholder} placeholderTextColor={colors.subtleText} style={styles.input} textAlignVertical="top" value={value} /></VGCard>;
}

const styles = StyleSheet.create({ safe: { backgroundColor: colors.background, flex: 1 }, flex: { flex: 1 }, scroll: { gap: spacing.lg, padding: spacing.screen, paddingBottom: 32 }, loading: { alignItems: "center", flex: 1, gap: spacing.sm, justifyContent: "center" }, back: { minHeight: 44, justifyContent: "center" }, backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis }, header: { gap: spacing.xxs }, eyebrow: { color: colors.forestGreen, ...typography.label }, title: { color: colors.primaryText, ...typography.title }, date: { color: colors.secondaryText, ...typography.caption }, card: { gap: spacing.sm }, disclosure: { gap: spacing.sm }, sectionTitle: { color: colors.primaryText, ...typography.heading }, verseText: { color: colors.primaryText, ...typography.body }, prompt: { color: colors.forestGreen, ...typography.bodyEmphasis }, shared: { color: colors.forestGreen, ...typography.caption }, private: { color: colors.secondaryText, ...typography.caption }, input: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 116, padding: spacing.md, ...typography.body }, muted: { color: colors.secondaryText, ...typography.caption }, error: { color: colors.destructive, ...typography.caption } });
