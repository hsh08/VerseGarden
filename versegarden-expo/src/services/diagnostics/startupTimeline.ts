type StartupDetails = Record<string, string | number | boolean | null | undefined>;

const launchStartedAt = Date.now();

export function traceStartup(event: string, details?: StartupDetails): void {
  if (!__DEV__) return;

  console.info(`[Startup +${Date.now() - launchStartedAt}ms] ${event}`, details ?? {});
}
