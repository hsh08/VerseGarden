import { createContext } from "react";

import type { FirebaseServices } from "@/services/firebase";

export type BootstrapState = { isReady: boolean; error: Error | null; firebase: FirebaseServices | null };

export const AppBootstrapContext = createContext<BootstrapState>({ isReady: false, error: null, firebase: null });
