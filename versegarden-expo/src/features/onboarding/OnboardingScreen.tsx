import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { InlineMessage } from "@/features/auth/InlineMessage";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";
import { VGPrimaryButton, VGSecondaryButton } from "@/components/ui";

const pages = [
  { title: "말씀으로 하루를 시작해요", description: "VerseGarden은 매일 말씀을 읽고, 필사하고, 기도하며 신앙 습관을 쌓아가는 공간이에요." },
  { title: "작은 기록이 정원이 돼요", description: "말씀 읽기, 필사, 기도, QT 완료 기록이 하루하루 쌓여 나만의 Garden으로 자라나요." },
  { title: "내게 필요한 말씀을 모아보세요", description: "마음에 남는 말씀을 저장하고, 다시 꺼내 보며 삶에 적용할 수 있어요." },
  { title: "관심 있는 말씀 주제를 골라보세요", description: "지금 마음에 가까운 주제를 골라 나의 신앙 기록을 더 나답게 정리해보세요." },
  { title: "대표 말씀은 나중에 선택할 수 있어요", description: "Profile에서 실제 성경 말씀을 검색해 나의 대표 말씀으로 설정할 수 있어요." },
] as const;

const topics = ["위로", "감사", "믿음", "불안", "진로", "관계", "기도", "회복"];

export function OnboardingScreen() {
  const { completeOnboarding, errorMessage, isSubmitting, clearError } = useAuthSession();
  const [page, setPage] = useState(0);
  const [selectedTopics, setSelectedTopics] = useState<string[]>([]);
  const current = pages[page];
  const isLastPage = page === pages.length - 1;

  const toggleTopic = (topic: string) => setSelectedTopics((selected) => selected.includes(topic) ? selected.filter((item) => item !== topic) : [...selected, topic]);
  const finish = () => { clearError(); void completeOnboarding(selectedTopics); };

  return <SafeAreaView edges={["top", "left", "right", "bottom"]} style={styles.safeArea}><ScrollView contentContainerStyle={styles.content}><View style={styles.top}><Text style={styles.brand}>VerseGarden</Text><Pressable accessibilityRole="button" disabled={isSubmitting} onPress={finish}><Text style={styles.skip}>건너뛰기</Text></Pressable></View><View style={styles.body}><Text style={styles.count}>{page + 1} / {pages.length}</Text><Text style={styles.title}>{current.title}</Text><Text style={styles.description}>{current.description}</Text>{page === 3 ? <View style={styles.topics}>{topics.map((topic) => { const selected = selectedTopics.includes(topic); return <Pressable accessibilityRole="checkbox" accessibilityState={{ checked: selected }} key={topic} onPress={() => toggleTopic(topic)} style={[styles.topic, selected && styles.topicSelected]}><Text style={[styles.topicText, selected && styles.topicTextSelected]}>{topic}</Text></Pressable>; })}</View> : null}</View><View style={styles.footer}><View style={styles.dots}>{pages.map((_, index) => <View key={index} style={[styles.dot, index === page && styles.dotActive]} />)}</View>{errorMessage ? <InlineMessage message={errorMessage} /> : null}<VGPrimaryButton disabled={isSubmitting} label={isSubmitting ? "저장 중..." : isLastPage ? "VerseGarden 시작하기" : "다음"} onPress={() => isLastPage ? finish() : setPage((value) => value + 1)} />{page > 0 ? <VGSecondaryButton disabled={isSubmitting} label="이전" onPress={() => setPage((value) => value - 1)} /> : null}</View></ScrollView></SafeAreaView>;
}

const styles = StyleSheet.create({
  safeArea: { backgroundColor: colors.background, flex: 1 },
  content: { flexGrow: 1, justifyContent: "space-between", padding: spacing.screen },
  top: { alignItems: "center", flexDirection: "row", justifyContent: "space-between" },
  brand: { color: colors.forestGreen, ...typography.label },
  skip: { color: colors.secondaryText, padding: spacing.xs, ...typography.caption },
  body: { gap: spacing.md, paddingVertical: spacing.lg },
  count: { color: colors.sageGreen, ...typography.label },
  title: { color: colors.primaryText, ...typography.display },
  description: { color: colors.secondaryText, ...typography.body },
  topics: { flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, marginTop: spacing.sm },
  topic: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.pill, borderWidth: 1, minHeight: 44, paddingHorizontal: spacing.md, justifyContent: "center" },
  topicSelected: { backgroundColor: colors.cardTint, borderColor: colors.sageGreen },
  topicText: { color: colors.secondaryText, ...typography.caption },
  topicTextSelected: { color: colors.forestGreen, ...typography.label },
  footer: { gap: spacing.sm },
  dots: { alignItems: "center", flexDirection: "row", gap: spacing.xxs, justifyContent: "center" },
  dot: { backgroundColor: colors.border, borderRadius: 4, height: 8, width: 8 },
  dotActive: { backgroundColor: colors.forestGreen, width: 24 },
});
