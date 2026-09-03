import { Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGPrimaryButton, VGSectionHeader } from "@/components/ui";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { useCommunity } from "@/providers/CommunityProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export default function ProfileTab() {
  const { profile, signOut, isSubmitting, errorMessage } = useAuthSession();
  const { memberships, selectedCommunity, isLoading, errorMessage: communityError, select } = useCommunity();
  const router = useRouter();
  const title = profile?.nickname || "VerseGarden 사용자";
  return <VGScreen><View style={styles.header}><Text style={styles.title}>Profile</Text><Text style={styles.description}>계정의 기본 정보를 확인합니다.</Text></View><VGCard><VGSectionHeader title={title} description={profile?.email ?? ""} />{profile?.favoriteVerse ? <Text style={styles.verse}>{profile.favoriteVerse}</Text> : <Text style={styles.muted}>대표 말씀은 이후 Verse 기능에서 선택할 수 있어요.</Text>}</VGCard><VGCard tinted style={styles.communityCard}><VGSectionHeader title="나의 공동체" description="함께 말씀을 묵상하는 공동체를 확인합니다." />{isLoading ? <Text style={styles.muted}>공동체 정보를 불러오는 중이에요.</Text> : selectedCommunity ? <><Pressable accessibilityRole="button" onPress={() => router.push({ pathname: "/community/[communityId]", params: { communityId: selectedCommunity.communityId } } as never)} style={styles.communityEntry}><View><Text style={styles.communityName}>{selectedCommunity.communityName}</Text><Text style={styles.role}>{selectedCommunity.role === "admin" ? "공동체 관리자" : selectedCommunity.role === "leader" ? "리더" : "멤버"}</Text></View><Text style={styles.open}>상세 보기</Text></Pressable>{memberships.length > 1 ? <View style={styles.communityChoices}>{memberships.map((item) => <Pressable key={item.communityId} accessibilityRole="button" onPress={() => void select(item.communityId)} style={[styles.choice, item.communityId === selectedCommunity.communityId && styles.choiceSelected]}><Text style={styles.choiceText}>{item.communityName}</Text></Pressable>)}</View> : null}</> : <Pressable accessibilityRole="button" onPress={() => router.push("/community/join" as never)} style={styles.join}><Text style={styles.joinLabel}>초대 코드로 공동체 참여하기</Text></Pressable>}{communityError ? <Text accessibilityRole="alert" style={styles.error}>{communityError}</Text> : null}</VGCard>{errorMessage ? <Text accessibilityRole="alert" style={styles.error}>{errorMessage}</Text> : null}<VGPrimaryButton disabled={isSubmitting} label={isSubmitting ? "로그아웃 중..." : "로그아웃"} onPress={() => void signOut()} /></VGScreen>;
}

const styles = StyleSheet.create({
  header: { gap: spacing.xs },
  title: { color: colors.primaryText, ...typography.title },
  description: { color: colors.secondaryText, ...typography.body },
  verse: { color: colors.forestGreen, marginTop: spacing.md, ...typography.bodyEmphasis },
  muted: { color: colors.secondaryText, marginTop: spacing.md, ...typography.caption },
  error: { color: colors.destructive, ...typography.caption },
  communityCard: { gap: spacing.md }, communityEntry: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", minHeight: 54 }, communityName: { color: colors.primaryText, ...typography.heading }, role: { color: colors.forestGreen, marginTop: spacing.xxs, ...typography.caption }, open: { color: colors.forestGreen, ...typography.bodyEmphasis }, join: { alignItems: "center", backgroundColor: colors.forestGreen, borderRadius: radius.medium, justifyContent: "center", minHeight: 48 }, joinLabel: { color: colors.cardBackground, ...typography.bodyEmphasis }, communityChoices: { gap: spacing.xs }, choice: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, minHeight: 42, justifyContent: "center", paddingHorizontal: spacing.md }, choiceSelected: { backgroundColor: colors.cardTint, borderColor: colors.forestGreen }, choiceText: { color: colors.primaryText, ...typography.caption },
});
