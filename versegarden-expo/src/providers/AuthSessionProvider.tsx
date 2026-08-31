import type { PropsWithChildren } from "react";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { User } from "firebase/auth";

import { authErrorMessage, profileErrorMessage } from "@/features/auth/authErrors";
import { type UserProfile } from "@/features/profile/UserProfile";
import { authService } from "@/services/auth/authService";
import { profileRepository } from "@/services/profile/profileRepository";

import { AppBootstrapContext } from "./AppBootstrapContext";

export type SessionPhase = "initializing" | "configurationError" | "signedOut" | "profileLoading" | "profileError" | "onboardingRequired" | "ready";

type AuthSessionContextValue = {
  phase: SessionPhase;
  user: User | null;
  profile: UserProfile | null;
  errorMessage: string | null;
  isSubmitting: boolean;
  signIn(email: string, password: string): Promise<boolean>;
  signUp(email: string, password: string): Promise<boolean>;
  sendPasswordReset(email: string): Promise<boolean>;
  completeOnboarding(selectedTopics: string[]): Promise<boolean>;
  selectWritingPlan(planId: string | null): Promise<boolean>;
  signOut(): Promise<boolean>;
  retryProfile(): Promise<void>;
  clearError(): void;
};

const AuthSessionContext = createContext<AuthSessionContextValue | null>(null);

export function AuthSessionProvider({ children }: PropsWithChildren) {
  const bootstrap = useContext(AppBootstrapContext);
  const [phase, setPhase] = useState<SessionPhase>("initializing");
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const activeUserID = useRef<string | null>(null);

  const loadProfile = useCallback(async (nextUser: User) => {
    setPhase("profileLoading");
    setProfile(null);
    setErrorMessage(null);
    try {
      const resolved = await profileRepository.ensureProfile(nextUser);
      if (activeUserID.current !== nextUser.uid) return;
      setProfile(resolved);
      setPhase(resolved.onboardingCompleted ? "ready" : "onboardingRequired");
    } catch (error) {
      if (activeUserID.current !== nextUser.uid) return;
      setProfile(null);
      setErrorMessage(profileErrorMessage(error));
      setPhase("profileError");
    }
  }, []);

  useEffect(() => {
    if (!bootstrap.isReady) return;
    let isMounted = true;
    const bootstrapError = bootstrap.error;
    if (bootstrapError) {
      void Promise.resolve().then(() => {
        if (!isMounted) return;
        setErrorMessage(bootstrapError.message);
        setPhase("configurationError");
      });
      return () => { isMounted = false; };
    }

    let unsubscribe: (() => void) | undefined;
    try {
      unsubscribe = authService.observe((nextUser) => {
        if (!isMounted) return;
        activeUserID.current = nextUser?.uid ?? null;
        setUser(nextUser);
        setProfile(null);
        setErrorMessage(null);
        setIsSubmitting(false);
        if (!nextUser) {
          setPhase("signedOut");
          return;
        }
        void loadProfile(nextUser);
      });
    } catch {
      void Promise.resolve().then(() => {
        if (!isMounted) return;
        setPhase("configurationError");
        setErrorMessage("Firebase 설정을 확인해주세요.");
      });
    }

    return () => {
      isMounted = false;
      unsubscribe?.();
    };
  }, [bootstrap.error, bootstrap.isReady, loadProfile]);

  const submit = useCallback(async (work: () => Promise<void>, action: "login" | "signup" | "reset" | "logout" | "onboarding"): Promise<boolean> => {
    setIsSubmitting(true);
    setErrorMessage(null);
    try {
      await work();
      return true;
    } catch (error) {
      setErrorMessage(authErrorMessage(error, action));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }, []);

  const value = useMemo<AuthSessionContextValue>(() => ({
    phase,
    user,
    profile,
    errorMessage,
    isSubmitting,
    signIn: async (email, password) => submit(() => authService.signIn(email, password).then(() => undefined), "login"),
    signUp: async (email, password) => submit(() => authService.signUp(email, password).then(() => undefined), "signup"),
    sendPasswordReset: async (email) => submit(() => authService.sendPasswordReset(email), "reset"),
    completeOnboarding: async (selectedTopics) => {
      if (!user) return false;
      return submit(async () => {
        const updated = await profileRepository.completeOnboarding(user, selectedTopics);
        setProfile(updated);
        setPhase("ready");
      }, "onboarding");
    },
    selectWritingPlan: async (planId) => {
      if (!user) return false;
      return submit(async () => {
        const updated = await profileRepository.updateSelectedWritingPlanId(user, planId);
        setProfile(updated);
      }, "onboarding");
    },
    signOut: async () => submit(async () => {
      await authService.signOut();
      activeUserID.current = null;
      setUser(null);
      setProfile(null);
      setPhase("signedOut");
    }, "logout"),
    retryProfile: async () => { if (user) await loadProfile(user); },
    clearError: () => setErrorMessage(null),
  }), [errorMessage, isSubmitting, loadProfile, phase, profile, submit, user]);

  return <AuthSessionContext.Provider value={value}>{children}</AuthSessionContext.Provider>;
}

export function useAuthSession(): AuthSessionContextValue {
  const context = useContext(AuthSessionContext);
  if (!context) throw new Error("useAuthSession must be used within AuthSessionProvider.");
  return context;
}
