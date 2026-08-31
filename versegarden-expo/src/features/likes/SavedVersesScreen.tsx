import { StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGEmptyStateView, VGSectionHeader } from "@/components/ui";
import { VerseRow } from "@/features/bible/VerseRow";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { usePersonalVerse } from "@/providers/PersonalVerseProvider";
import { colors, spacing, typography } from "@/theme/tokens";

export function SavedVersesScreen() {
  const router = useRouter(); const { repository } = useBibleRepository(); const { likes } = usePersonalVerse();
  if (!repository) return <VGScreen><Text style={styles.loading}>말씀을 준비하고 있어요.</Text></VGScreen>;
  const verses = likes.flatMap((like) => { const verse = repository.getVerse(like.verseId); return verse ? [verse] : []; });
  return <VGScreen><View style={styles.header}><Text style={styles.title}>저장한 말씀</Text><Text style={styles.subtitle}>마음에 남은 말씀을 다시 꺼내보세요.</Text></View>{verses.length === 0 ? <VGEmptyStateView description="말씀 상세에서 저장하면 이곳에 모여요." title="아직 저장한 말씀이 없어요" /> : <View style={styles.list}><VGSectionHeader description={`${verses.length}개 저장됨`} title="말씀 보관함" />{verses.map((verse) => <VerseRow key={verse.id} onPress={() => router.push({ pathname: "/verse/[verseId]", params: { verseId: verse.id } })} verse={verse} />)}</View>}</VGScreen>;
}
const styles = StyleSheet.create({ header: { gap: spacing.xxs }, title: { color: colors.primaryText, ...typography.title }, subtitle: { color: colors.secondaryText, ...typography.body }, list: { gap: spacing.sm }, loading: { color: colors.secondaryText, ...typography.body } });
