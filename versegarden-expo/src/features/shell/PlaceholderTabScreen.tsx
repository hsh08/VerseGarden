import { StyleSheet, Text, View } from "react-native";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView, VGPrimaryButton, VGSectionHeader } from "@/components/ui";
import { colors, spacing, typography } from "@/theme/tokens";

type PlaceholderTabScreenProps = { title: string; description: string; home?: boolean };

export function PlaceholderTabScreen({ title, description, home = false }: PlaceholderTabScreenProps) {
  return (
    <VGScreen>
      <View style={styles.brandBlock}>
        {home ? <Text style={styles.brand}>VerseGarden</Text> : null}
        <Text style={home ? styles.homeTitle : styles.title}>{title}</Text>
        <Text style={styles.description}>{description}</Text>
      </View>
      {home ? <>
        <VGCard tinted>
          <VGSectionHeader title="Android foundation" description="탭, 디자인 시스템, 로컬 초기화 기반을 먼저 준비했습니다." />
          <View style={styles.cardAction}><VGPrimaryButton disabled label="다음 단계에서 연결" onPress={() => undefined} /></View>
        </VGCard>
        <VGCard><VGEmptyStateView title="아직 표시할 기록이 없습니다" description="Auth, 말씀, 기록 기능은 이후 단계에서 실제 데이터와 연결됩니다." /></VGCard>
      </> : <VGCard><VGEmptyStateView title="준비 중인 탭입니다" description="현재는 앱 구조와 탐색 흐름만 검증합니다." /></VGCard>}
    </VGScreen>
  );
}

const styles = StyleSheet.create({
  brandBlock: { gap: spacing.xs, paddingTop: spacing.sm },
  brand: { color: colors.forestGreen, ...typography.label },
  title: { color: colors.primaryText, ...typography.title },
  homeTitle: { color: colors.primaryText, ...typography.display },
  description: { color: colors.secondaryText, ...typography.body },
  cardAction: { marginTop: spacing.md },
});
