export type PasswordValidationResult = {
  hasMinimumLength: boolean;
  containsLetter: boolean;
  containsNumber: boolean;
  containsSpecialCharacter: boolean;
  matchesConfirmation: boolean;
  meetsContentRequirements: boolean;
  isValid: boolean;
};

export const passwordPolicyMessage = "비밀번호는 8자 이상이며, 영문·숫자·특수문자를 모두 포함해야 합니다.";

export function validatePassword(password: string, confirmation: string): PasswordValidationResult {
  const hasMinimumLength = password.length >= 8;
  const containsLetter = /[A-Za-z]/.test(password);
  const containsNumber = /[0-9]/.test(password);
  const containsSpecialCharacter = /[!@#$%^&*()_+\-=?.,]/.test(password);
  const matchesConfirmation = password.length > 0 && password === confirmation;
  const meetsContentRequirements = hasMinimumLength && containsLetter && containsNumber && containsSpecialCharacter;

  return { hasMinimumLength, containsLetter, containsNumber, containsSpecialCharacter, matchesConfirmation, meetsContentRequirements, isValid: meetsContentRequirements && matchesConfirmation };
}

export function isValidEmail(email: string): boolean {
  const [localPart, domain, ...rest] = email.trim().split("@");
  return Boolean(localPart && domain && domain.includes(".") && rest.length === 0);
}

export function hasGmailTypo(email: string): boolean {
  const domain = email.trim().toLowerCase().split("@")[1] ?? "";
  return ["gmial.com", "gmil.com", "gamil.com", "gmaill.com"].includes(domain);
}
