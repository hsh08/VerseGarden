import { useEffect, useState } from "react";
import { ActivityIndicator, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView, VGSectionHeader } from "@/components/ui";
import { useBibleRepository } from "@/features/bible/useBibleRepository";
import { qtRepository } from "@/features/qt/qtRepository";
import { useCommunity } from "@/providers/CommunityProvider";
import { colors, spacing, typography } from "@/theme/tokens";

export default function CommunityDetailScreen() {
  const { communityId } = useLocalSearchParams<{ communityId: string }>(); const { memberships, selectedCommunity } = useCommunity(); const { repository } = useBibleRepository();
  const community = memberships.find((item) => item.communityId === communityId) ?? null; const [hasTodayQT, setHasTodayQT] = useState<boolean | null>(null);
  useEffect(() => { if (!repository || !community) return; let active = true; void qtRepository.resolveToday(repository, new Date(), community).then((content) => { if (active) setHasTodayQT(content.source === "community"); }).catch(() => { if (active) setHasTodayQT(false); }); return () => { active = false; }; }, [community, repository]);
  if (!community) return <VGScreen><VGEmptyStateView title="공동체를 찾을 수 없어요" description="현재 계정에서 접근할 수 있는 공동체인지 확인해주세요." /></VGScreen>;
  return <VGScreen><View style={styles.header}><Text style={styles.title}>{community.communityName}</Text><Text style={styles.description}>{community.communityStatus === "active" ? "함께 말씀을 묵상하는 공동체" : "현재 활동하지 않는 공동체"}</Text></View><VGCard><VGSectionHeader title="내 공동체 정보" description={community.role === "admin" ? "공동체 관리자" : community.role === "leader" ? "리더" : "멤버"} /><Text style={styles.value}>가입일 {community.joinedAt.toLocaleDateString("ko-KR")}</Text>{typeof community.memberCount === "number" ? <Text style={styles.value}>구성원 {community.memberCount}명</Text> : null}{selectedCommunity?.communityId === community.communityId ? <Text style={styles.selected}>현재 선택된 공동체</Text> : null}</VGCard><VGCard>{hasTodayQT === null ? <ActivityIndicator color={colors.forestGreen} /> : <VGSectionHeader title="오늘의 공동체 QT" description={hasTodayQT ? "오늘의 공동체 QT가 준비되어 있어요." : "오늘은 공동체 QT가 없어요. 기본 QT를 사용할 수 있어요."} />}</VGCard></VGScreen>;
}

const styles = StyleSheet.create({ header: { gap: spacing.xs }, title: { color: colors.primaryText, ...typography.title }, description: { color: colors.secondaryText, ...typography.body }, value: { color: colors.secondaryText, marginTop: spacing.sm, ...typography.body }, selected: { color: colors.forestGreen, marginTop: spacing.md, ...typography.caption } });
