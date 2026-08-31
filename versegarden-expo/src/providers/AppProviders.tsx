import type { PropsWithChildren } from "react";
import { useEffect, useMemo, useState } from "react";

import { getFirebaseServices } from "@/services/firebase";
import { initializeDatabase } from "@/services/persistence/database";

import { AuthSessionProvider } from "./AuthSessionProvider";
import { PersonalVerseProvider } from "./PersonalVerseProvider";
import { QuietPrayerProvider } from "./QuietPrayerProvider";
import { GardenProvider } from "./GardenProvider";
import { AppBootstrapContext, type BootstrapState } from "./AppBootstrapContext";

export { AppBootstrapContext } from "./AppBootstrapContext";

export function AppProviders({ children }: PropsWithChildren) {
  const [state, setState] = useState<BootstrapState>({ isReady: false, error: null, firebase: null });

  useEffect(() => {
    let isMounted = true;
    void Promise.resolve().then(async () => {
      const firebase = getFirebaseServices();
      await initializeDatabase();
      if (isMounted) setState({ isReady: true, error: null, firebase });
    }).catch((error: unknown) => {
      if (isMounted) setState({ isReady: true, error: error instanceof Error ? error : new Error("App initialization failed."), firebase: null });
    });
    return () => { isMounted = false; };
  }, []);

  const value = useMemo(() => state, [state]);
  return <AppBootstrapContext.Provider value={value}><AuthSessionProvider><PersonalVerseProvider><QuietPrayerProvider><GardenProvider>{children}</GardenProvider></QuietPrayerProvider></PersonalVerseProvider></AuthSessionProvider></AppBootstrapContext.Provider>;
}
