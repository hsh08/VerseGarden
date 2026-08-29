"use client";

import {
  User,
  getIdTokenResult,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut
} from "firebase/auth";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState
} from "react";
import { getMyAdminCommunities } from "@/lib/adminScope";
import { auth, hasFirebaseWebConfig } from "@/lib/firebase";
import type { CommunityAdminScope } from "@/types/community";

export type AdminAuthState =
  | "loading"
  | "signedOut"
  | "denied"
  | "platformAdmin"
  | "communityAdmin";

type AdminAuthContextValue = {
  state: AdminAuthState;
  user: User | null;
  error: string | null;
  isConfigured: boolean;
  communityScopes: CommunityAdminScope[];
  selectedCommunityId: string | null;
  setSelectedCommunityId: (communityId: string) => void;
  signIn: (email: string, password: string) => Promise<void>;
  signOutAdmin: () => Promise<void>;
  refreshClaims: () => Promise<void>;
};

const AdminAuthContext = createContext<AdminAuthContextValue | null>(null);

export function AdminAuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AdminAuthState>("loading");
  const [user, setUser] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [communityScopes, setCommunityScopes] = useState<CommunityAdminScope[]>([]);
  const [selectedCommunityId, setSelectedCommunityIdState] = useState<string | null>(null);
  const isConfigured = hasFirebaseWebConfig();

  const resolveAdminState = useCallback(async (nextUser: User | null) => {
    setError(null);

    if (!nextUser) {
      setUser(null);
      setCommunityScopes([]);
      setSelectedCommunityIdState(null);
      setState("signedOut");
      return;
    }

    setUser(nextUser);
    setState("loading");

    try {
      const token = await getIdTokenResult(nextUser, true);
      if (token.claims.admin === true) {
        setCommunityScopes([]);
        setSelectedCommunityIdState(null);
        setState("platformAdmin");
        return;
      }

      const scopes = await getMyAdminCommunities();
      setCommunityScopes(scopes);
      setSelectedCommunityIdState((current) =>
        current && scopes.some((scope) => scope.communityId === current)
          ? current
          : (scopes[0]?.communityId ?? null)
      );
      setState(scopes.length ? "communityAdmin" : "denied");
    } catch {
      setCommunityScopes([]);
      setSelectedCommunityIdState(null);
      setState("denied");
      setError("관리자 권한을 확인하지 못했습니다.");
    }
  }, []);

  useEffect(() => {
    if (!isConfigured) {
      setState("signedOut");
      setError("Firebase Web 설정이 필요합니다.");
      return;
    }

    return onAuthStateChanged(auth, (nextUser) => {
      void resolveAdminState(nextUser);
    });
  }, [isConfigured, resolveAdminState]);

  const signIn = useCallback(
    async (email: string, password: string) => {
      setError(null);
      const credential = await signInWithEmailAndPassword(auth, email, password);
      await resolveAdminState(credential.user);
    },
    [resolveAdminState]
  );

  const signOutAdmin = useCallback(async () => {
    await signOut(auth);
    setUser(null);
    setCommunityScopes([]);
    setSelectedCommunityIdState(null);
    setState("signedOut");
  }, []);

  const setSelectedCommunityId = useCallback(
    (communityId: string) => {
      if (communityScopes.some((scope) => scope.communityId === communityId)) {
        setSelectedCommunityIdState(communityId);
      }
    },
    [communityScopes]
  );

  const refreshClaims = useCallback(async () => {
    await resolveAdminState(auth.currentUser);
  }, [resolveAdminState]);

  const value = useMemo(
    () => ({
      state,
      user,
      error,
      isConfigured,
      communityScopes,
      selectedCommunityId,
      setSelectedCommunityId,
      signIn,
      signOutAdmin,
      refreshClaims
    }),
    [
      state,
      user,
      error,
      isConfigured,
      communityScopes,
      selectedCommunityId,
      setSelectedCommunityId,
      signIn,
      signOutAdmin,
      refreshClaims
    ]
  );

  return <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>;
}

export function useAdminAuth() {
  const value = useContext(AdminAuthContext);
  if (!value) {
    throw new Error("useAdminAuth must be used inside AdminAuthProvider.");
  }
  return value;
}
