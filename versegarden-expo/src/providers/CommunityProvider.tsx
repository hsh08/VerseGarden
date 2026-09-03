import AsyncStorage from "@react-native-async-storage/async-storage";
import type { PropsWithChildren } from "react";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import { communityErrorMessage, communityService } from "@/features/community/communityService";
import { selectCommunity, type CommunityJoinResult, type CommunityMembership } from "@/features/community/communityTypes";
import { useAuthSession } from "@/providers/AuthSessionProvider";
import { traceStartup } from "@/services/diagnostics/startupTimeline";

type CommunityContextValue = {
  memberships: readonly CommunityMembership[];
  selectedCommunity: CommunityMembership | null;
  isLoading: boolean;
  hasLoaded: boolean;
  errorMessage: string | null;
  refresh(): Promise<void>;
  select(communityId: string): Promise<void>;
  redeemInvite(code: string): Promise<CommunityJoinResult>;
};

const CommunityContext = createContext<CommunityContextValue | null>(null);
const selectionKey = (uid: string) => `versegarden:selectedCommunity:${uid}`;

export function CommunityProvider({ children }: PropsWithChildren) {
  const { phase, user } = useAuthSession();
  const [memberships, setMemberships] = useState<CommunityMembership[]>([]);
  const [selectedCommunity, setSelectedCommunity] = useState<CommunityMembership | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [hasLoaded, setHasLoaded] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const uidRef = useRef<string | null>(null);

  const load = useCallback(async (force = false) => {
    const uid = user?.uid ?? null;
    if (phase !== "ready" || !uid) {
      uidRef.current = null; setMemberships([]); setSelectedCommunity(null); setHasLoaded(false); setErrorMessage(null); return;
    }
    if (!force && hasLoaded && uidRef.current === uid) return;
    uidRef.current = uid;
    traceStartup("Community membership load started");
    setIsLoading(true); setErrorMessage(null);
    try {
      const [next, stored] = await Promise.all([communityService.getMyCommunities(), AsyncStorage.getItem(selectionKey(uid))]);
      if (uidRef.current !== uid) return;
      const selected = selectCommunity(next, stored);
      setMemberships(next); setSelectedCommunity(selected);
      traceStartup("Community membership load completed", { membershipCount: next.length, selected: Boolean(selected) });
      if (selected?.communityId !== stored) {
        if (selected) await AsyncStorage.setItem(selectionKey(uid), selected.communityId);
        else await AsyncStorage.removeItem(selectionKey(uid));
      }
    } catch (error) {
      if (uidRef.current === uid) { setMemberships([]); setSelectedCommunity(null); setErrorMessage(communityErrorMessage(error, "load")); traceStartup("Community membership load failed"); }
    } finally {
      if (uidRef.current === uid) { setHasLoaded(true); setIsLoading(false); }
    }
  }, [hasLoaded, phase, user?.uid]);

  useEffect(() => { const task = setTimeout(() => { void load(); }, 0); return () => clearTimeout(task); }, [load]);

  const refresh = useCallback(() => load(true), [load]);
  const select = useCallback(async (communityId: string) => {
    const uid = user?.uid;
    const selected = selectCommunity(memberships, communityId);
    if (!uid || !selected || selected.communityId !== communityId) return;
    setSelectedCommunity(selected);
    await AsyncStorage.setItem(selectionKey(uid), selected.communityId);
  }, [memberships, user?.uid]);
  const redeemInvite = useCallback(async (code: string) => {
    const result = await communityService.redeemInvite(code);
    const uid = user?.uid;
    if (uid) await AsyncStorage.setItem(selectionKey(uid), result.communityId);
    await load(true);
    return result;
  }, [load, user?.uid]);

  const value = useMemo<CommunityContextValue>(() => ({ memberships, selectedCommunity, isLoading, hasLoaded, errorMessage, refresh, select, redeemInvite }), [errorMessage, hasLoaded, isLoading, memberships, redeemInvite, refresh, select, selectedCommunity]);
  return <CommunityContext.Provider value={value}>{children}</CommunityContext.Provider>;
}

export function useCommunity(): CommunityContextValue {
  const context = useContext(CommunityContext);
  if (!context) throw new Error("useCommunity must be used within CommunityProvider.");
  return context;
}
