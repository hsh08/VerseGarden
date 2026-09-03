import { useState } from "react";
import { Alert, StyleSheet, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGPrimaryButton } from "@/components/ui";
import { communityErrorMessage } from "@/features/community/communityService";
import { useCommunity } from "@/providers/CommunityProvider";
import { colors, radius, spacing, typography } from "@/theme/tokens";

export default function CommunityJoinScreen() {
  const { redeemInvite } = useCommunity(); const router = useRouter();
  const [code, setCode] = useState(""); const [isSubmitting, setIsSubmitting] = useState(false); const [error, setError] = useState<string | null>(null);
  const join = async () => { if (!code.trim() || isSubmitting) return; setIsSubmitting(true); setError(null); try { const result = await redeemInvite(code); Alert.alert("공동체에 참여했어요", result.alreadyMember ? "이미 참여 중인 공동체입니다." : `${result.communityName}에 참여했어요.`, [{ text: "확인", onPress: () => router.replace({ pathname: "/community/[communityId]", params: { communityId: result.communityId } } as never) }]); } catch (reason) { setError(communityErrorMessage(reason, "join")); } finally { setIsSubmitting(false); } };
  return <VGScreen><View style={styles.header}><Text style={styles.title}>공동체 참여</Text><Text style={styles.description}>초대 코드를 입력하면 공동체에 참여할 수 있어요.</Text></View><VGCard style={styles.card}><Text style={styles.label}>초대 코드</Text><TextInput autoCapitalize="characters" autoCorrect={false} accessibilityLabel="초대 코드" onChangeText={(value) => setCode(value.toUpperCase())} placeholder="초대 코드를 입력해주세요" placeholderTextColor={colors.subtleText} style={styles.input} value={code} />{error ? <Text accessibilityRole="alert" style={styles.error}>{error}</Text> : null}<VGPrimaryButton disabled={!code.trim() || isSubmitting} label={isSubmitting ? "참여 중..." : "공동체 참여하기"} onPress={() => void join()} /></VGCard></VGScreen>;
}

const styles = StyleSheet.create({ header: { gap: spacing.xs }, title: { color: colors.primaryText, ...typography.title }, description: { color: colors.secondaryText, ...typography.body }, card: { gap: spacing.md }, label: { color: colors.primaryText, ...typography.bodyEmphasis }, input: { borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 50, paddingHorizontal: spacing.md, ...typography.body }, error: { color: colors.destructive, ...typography.caption } });
