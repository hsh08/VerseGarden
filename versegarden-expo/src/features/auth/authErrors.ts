import { FirebaseError } from "firebase/app";

export function authErrorMessage(error: unknown, action: "login" | "signup" | "reset" | "logout" | "onboarding" = "login"): string {
  const code = error instanceof FirebaseError ? error.code : "";
  switch (code) {
    case "auth/invalid-email": return "이메일 형식이 올바르지 않습니다.";
    case "auth/user-not-found": return "가입되지 않은 이메일입니다.";
    case "auth/wrong-password":
    case "auth/invalid-credential": return "이메일 또는 비밀번호가 올바르지 않습니다.";
    case "auth/email-already-in-use": return "이미 가입된 이메일입니다.";
    case "auth/weak-password": return "비밀번호는 8자 이상이며, 영문·숫자·특수문자를 모두 포함해야 합니다.";
    case "auth/network-request-failed": return "네트워크 연결을 확인해주세요.";
    case "auth/too-many-requests": return "잠시 후 다시 시도해주세요.";
    default:
      if (action === "reset") return "비밀번호 재설정 메일을 보내지 못했습니다. 이메일 주소를 확인한 뒤 다시 시도해주세요.";
      if (action === "signup") return "회원가입 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.";
      if (action === "onboarding") return "온보딩 설정을 저장하지 못했습니다. 다시 시도해주세요.";
      if (action === "logout") return "로그아웃하지 못했습니다. 다시 시도해주세요.";
      return "로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.";
  }
}

export function profileErrorMessage(error: unknown): string {
  const code = error instanceof FirebaseError ? error.code : "";
  if (code === "permission-denied") return "프로필에 접근할 권한이 없습니다. 다시 로그인한 뒤 시도해주세요.";
  if (code === "unavailable" || code === "deadline-exceeded") return "네트워크 연결을 확인한 뒤 프로필을 다시 불러와주세요.";
  return "프로필 정보를 불러오지 못했습니다. 다시 시도해주세요.";
}
