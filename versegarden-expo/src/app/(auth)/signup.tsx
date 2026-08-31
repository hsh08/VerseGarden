import { useState } from "react";
import { StyleSheet, Text } from "react-native";
import { useRouter } from "expo-router";

import { AuthTextField } from "@/components/auth/AuthTextField";
import { VGPrimaryButton, VGSecondaryButton } from "@/components/ui";
import { AuthScreen } from "@/features/auth/AuthScreen";
import { hasGmailTypo, isValidEmail, passwordPolicyMessage, validatePassword } from "@/features/auth/authValidation";
import { InlineMessage } from "@/features/auth/InlineMessage";
import { PasswordChecklist } from "@/features/auth/PasswordChecklist";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, typography } from "@/theme/tokens";

export default function SignupScreen() {
  const router = useRouter();
  const { signUp, isSubmitting, errorMessage, clearError } = useAuthSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const trimmedEmail = email.trim();
  const validation = validatePassword(password, confirmation);
  const canSubmit = isValidEmail(trimmedEmail) && !hasGmailTypo(trimmedEmail) && validation.isValid && !isSubmitting;

  const submit = () => { if (!canSubmit) return; clearError(); void signUp(trimmedEmail, password); };

  return <AuthScreen title="VerseGarden 시작하기" description="나만의 조용한 기록의 정원을 만들어보세요."><AuthTextField autoComplete="email" keyboardType="email-address" label="이메일" onChangeText={setEmail} placeholder="example@email.com" value={email} /><AuthTextField autoComplete="new-password" label="비밀번호" onChangeText={setPassword} placeholder="비밀번호" secure value={password} /><AuthTextField autoComplete="new-password" label="비밀번호 확인" onChangeText={setConfirmation} onSubmitEditing={submit} placeholder="비밀번호를 다시 입력해주세요" secure value={confirmation} /><PasswordChecklist validation={validation} />{!password || validation.meetsContentRequirements ? null : <Text style={styles.hint}>{passwordPolicyMessage}</Text>}{hasGmailTypo(trimmedEmail) ? <InlineMessage message="gmail.com을 입력하려던 건가요?" /> : null}{errorMessage ? <InlineMessage message={errorMessage} /> : null}<VGPrimaryButton disabled={!canSubmit} label={isSubmitting ? "회원가입 중..." : "이메일로 회원가입"} onPress={submit} /><VGSecondaryButton label="이미 계정이 있나요? 로그인" onPress={() => router.replace("/(auth)/login")} /></AuthScreen>;
}

const styles = StyleSheet.create({ hint: { color: colors.secondaryText, ...typography.caption } });
