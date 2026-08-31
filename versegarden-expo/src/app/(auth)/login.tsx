import { useState } from "react";
import { Pressable, StyleSheet, Text } from "react-native";
import { useRouter } from "expo-router";

import { AuthTextField } from "@/components/auth/AuthTextField";
import { VGPrimaryButton, VGSecondaryButton } from "@/components/ui";
import { AuthScreen } from "@/features/auth/AuthScreen";
import { hasGmailTypo, isValidEmail } from "@/features/auth/authValidation";
import { InlineMessage } from "@/features/auth/InlineMessage";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { colors, typography } from "@/theme/tokens";

export default function LoginScreen() {
  const router = useRouter();
  const { signIn, isSubmitting, errorMessage, clearError } = useAuthSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const trimmedEmail = email.trim();

  const submit = () => {
    clearError();
    if (!trimmedEmail || !password) return;
    if (!isValidEmail(trimmedEmail) || hasGmailTypo(trimmedEmail)) return;
    void signIn(trimmedEmail, password);
  };

  return <AuthScreen title="다시 만나서 반가워요" description="말씀과 기록의 정원으로 돌아오세요."><AuthTextField autoComplete="email" keyboardType="email-address" label="이메일" onChangeText={setEmail} placeholder="example@email.com" returnKeyType="next" value={email} /><AuthTextField autoComplete="current-password" label="비밀번호" onChangeText={setPassword} onSubmitEditing={submit} placeholder="비밀번호" returnKeyType="done" secure value={password} />{hasGmailTypo(trimmedEmail) ? <InlineMessage message="gmail.com을 입력하려던 건가요?" /> : null}{errorMessage ? <InlineMessage message={errorMessage} /> : null}<VGPrimaryButton accessibilityLabel="이메일로 로그인" disabled={isSubmitting || !isValidEmail(trimmedEmail) || !password} label={isSubmitting ? "로그인 중..." : "이메일로 로그인"} onPress={submit} /><Pressable accessibilityRole="button" onPress={() => router.push("/(auth)/forgot-password")} style={styles.forgot}><Text style={styles.forgotText}>비밀번호를 잊으셨나요?</Text></Pressable><VGSecondaryButton label="계정이 없나요? 회원가입" onPress={() => router.push("/(auth)/signup")} /></AuthScreen>;
}

const styles = StyleSheet.create({ forgot: { alignSelf: "flex-end", paddingVertical: 4 }, forgotText: { color: colors.forestGreen, ...typography.caption } });
