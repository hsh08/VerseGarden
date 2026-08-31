import { StyleSheet, Text, View } from "react-native";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGPrimaryButton, VGSectionHeader } from "@/components/ui";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, spacing, typography } from "@/theme/tokens";

export default function ProfileTab() {
  const { profile, signOut, isSubmitting, errorMessage } = useAuthSession();
  const title = profile?.nickname || "VerseGarden 사용자";
  return <VGScreen><View style={styles.header}><Text style={styles.title}>Profile</Text><Text style={styles.description}>계정의 기본 정보를 확인합니다.</Text></View><VGCard><VGSectionHeader title={title} description={profile?.email ?? ""} />{profile?.favoriteVerse ? <Text style={styles.verse}>{profile.favoriteVerse}</Text> : <Text style={styles.muted}>대표 말씀은 이후 Verse 기능에서 선택할 수 있어요.</Text>}</VGCard>{errorMessage ? <Text accessibilityRole="alert" style={styles.error}>{errorMessage}</Text> : null}<VGPrimaryButton disabled={isSubmitting} label={isSubmitting ? "로그아웃 중..." : "로그아웃"} onPress={() => void signOut()} /></VGScreen>;
}

const styles = StyleSheet.create({
  header: { gap: spacing.xs },
  title: { color: colors.primaryText, ...typography.title },
  description: { color: colors.secondaryText, ...typography.body },
  verse: { color: colors.forestGreen, marginTop: spacing.md, ...typography.bodyEmphasis },
  muted: { color: colors.secondaryText, marginTop: spacing.md, ...typography.caption },
  error: { color: colors.destructive, ...typography.caption },
});
