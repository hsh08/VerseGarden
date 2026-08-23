export function friendlyErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    const message = error.message.toLowerCase();
    if (message.includes("permission-denied") || message.includes("missing or insufficient")) {
      return "관리자 권한이 없습니다.";
    }
    return error.message;
  }
  return "요청을 처리하지 못했습니다.";
}
