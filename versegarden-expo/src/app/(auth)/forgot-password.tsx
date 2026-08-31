import { useState } from "react";
import { Text } from "react-native";
import { useRouter } from "expo-router";

import { AuthTextField } from "@/components/auth/AuthTextField";
import { VGPrimaryButton, VGSecondaryButton } from "@/components/ui";
import { AuthScreen } from "@/features/auth/AuthScreen";
import { isValidEmail } from "@/features/auth/authValidation";
import { InlineMessage } from "@/features/auth/InlineMessage";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, typography } from "@/theme/tokens";

export default function ForgotPasswordScreen() {
  const router = useRouter();
  const { sendPasswordReset, isSubmitting, errorMessage, clearError } = useAuthSession();
  const [email, setEmail] = useState("");
  const [success, setSuccess] = useState(false);
  const trimmedEmail = email.trim();
  const send = async () => { if (!isValidEmail(trimmedEmail) || isSubmitting) return; clearError(); if (await sendPasswordReset(trimmedEmail)) setSuccess(true); };
  return <AuthScreen title="비밀번호 재설정" description="가입한 이메일을 입력하면 비밀번호 재설정 메일을 보내드립니다."><AuthTextField autoComplete="email" keyboardType="email-address" label="이메일" onChangeText={(value) => { setEmail(value); setSuccess(false); }} placeholder="example@email.com" value={email} />{!trimmedEmail || isValidEmail(trimmedEmail) ? null : <Text style={{ color: colors.destructive, ...typography.caption }}>이메일 형식이 올바르지 않습니다.</Text>}{success ? <InlineMessage success message="입력한 이메일로 비밀번호 재설정 메일을 보냈습니다. 메일함을 확인해주세요." /> : null}{errorMessage ? <InlineMessage message={errorMessage} /> : null}<VGPrimaryButton disabled={isSubmitting || !isValidEmail(trimmedEmail)} label={isSubmitting ? "보내는 중..." : "재설정 메일 보내기"} onPress={() => void send()} /><VGSecondaryButton label="로그인으로 돌아가기" onPress={() => router.replace("/(auth)/login")} /></AuthScreen>;
}
