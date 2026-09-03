import type { PropsWithChildren } from "react";
import { AppState } from "react-native";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import type { QTContent, QTRecord } from "@/features/qt/qtTypes";
import { qtRepository } from "@/features/qt/qtRepository";
import { prayerRepository } from "@/features/prayer/prayerRepository";
import type { PrayerRecord } from "@/features/prayer/prayerTypes";
import { personalErrorMessage } from "@/features/shared/firestore";
import { communityService } from "@/features/community/communityService";
import { isRetryableCommunityError, makeCommunitySubmissionRequest, pendingSubmissionFor, type PendingCommunitySubmission } from "@/features/community/communityTypes";
import { preferences } from "@/services/persistence/preferences";

import { useAuthSession } from "./AuthSessionProvider";

type QuietPrayerContextValue = {
  qtRecords: readonly QTRecord[];
  prayerRecords: readonly PrayerRecord[];
  errorMessage: string | null;
  qtRecord(dateKey?: string): QTRecord | null;
  saveQTDraft(content: QTContent, answers: Pick<QTRecord, "reflectionAnswer" | "applicationText" | "prayerText">): Promise<void>;
  completeQT(content: QTContent, answers: Pick<QTRecord, "reflectionAnswer" | "applicationText" | "prayerText">): Promise<void>;
  createPrayer(title: string, userText: string): Promise<void>;
  updatePrayer(recordId: string, title: string, userText: string): Promise<void>;
  deletePrayer(recordId: string): Promise<void>;
};

const QuietPrayerContext = createContext<QuietPrayerContextValue | null>(null);

const retryPreference = "communityQTRetry";

function upsertQTRecord(records: QTRecord[], next: QTRecord): QTRecord[] {
  const index = records.findIndex((record) => record.id === next.id);
  const updated = index >= 0
    ? records.map((record) => record.id === next.id ? next : record)
    : [...records, next];

  return updated.sort((left, right) => right.date.getTime() - left.date.getTime());
}

export function QuietPrayerProvider({ children }: PropsWithChildren) {
  const { phase, user } = useAuthSession();
  const [qtRecords, setQTRecords] = useState<QTRecord[]>([]);
  const [prayerRecords, setPrayerRecords] = useState<PrayerRecord[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const pendingRef = useRef<PendingCommunitySubmission[]>([]);
  const flushingRef = useRef(false);
  const active = phase === "ready";

  useEffect(() => {
    if (!active) {
      const clear = setTimeout(() => { setQTRecords([]); setPrayerRecords([]); setErrorMessage(null); }, 0);
      return () => clearTimeout(clear);
    }
    let mounted = true;
    const fail = (fallback: string) => (error: unknown) => { if (mounted) setErrorMessage(personalErrorMessage(error, fallback)); };
    const stopQT = qtRepository.subscribe((records) => { if (mounted) setQTRecords(records); }, fail("QT 기록을 불러오지 못했습니다."));
    const stopPrayer = prayerRepository.subscribe((records) => { if (mounted) setPrayerRecords(records); }, fail("기도 기록을 불러오지 못했습니다."));
    return () => { mounted = false; stopQT(); stopPrayer(); };
  }, [active]);

  const persistPending = useCallback(async (uid: string) => {
    await preferences.set(uid, retryPreference, pendingRef.current);
  }, []);

  const submitCompletedCommunityRecord = useCallback(async (record: QTRecord, pending: PendingCommunitySubmission, uid: string) => {
    const request = makeCommunitySubmissionRequest(record);
    if (!request) return;
    if (__DEV__) console.info("[QT Complete] community submit start", { contentVersion: request.contentVersion, source: "community" });
    try {
      const result = await communityService.submitQT(request);
      pendingRef.current = pendingRef.current.filter((item) => item.recordId !== pending.recordId || item.communityId !== pending.communityId || item.dateKey !== pending.dateKey);
      await persistPending(uid);
      if (__DEV__) console.info("[QT Complete] community submit success", { alreadySubmitted: result.alreadySubmitted });
    } catch (error) {
      if (!isRetryableCommunityError(error)) {
        pendingRef.current = pendingRef.current.filter((item) => item.recordId !== pending.recordId || item.communityId !== pending.communityId || item.dateKey !== pending.dateKey);
        await persistPending(uid);
      }
      if (__DEV__) console.info("[QT Complete] community submit failed", { retryable: isRetryableCommunityError(error) });
    }
  }, [persistPending]);

  const flushCommunitySubmissions = useCallback(async () => {
    const uid = user?.uid;
    if (!uid || !pendingRef.current.length || flushingRef.current) return;
    flushingRef.current = true;
    try {
      const remaining: PendingCommunitySubmission[] = [];
      for (const item of pendingRef.current) {
        const record = qtRecords.find((candidate) => candidate.id === item.recordId) ?? qtRecords.find((candidate) => candidate.dateKey === item.dateKey);
        const request = record ? makeCommunitySubmissionRequest(record) : null;
        if (!request || request.communityId !== item.communityId || request.dateKey !== item.dateKey || request.contentId !== item.contentId || request.contentVersion !== item.contentVersion) {
          remaining.push(item);
          continue;
        }
        try {
          await communityService.submitQT(request);
        } catch (error) {
          if (isRetryableCommunityError(error)) remaining.push(item);
        }
      }
      if (user?.uid !== uid) return;
      pendingRef.current = remaining;
      await persistPending(uid);
    } finally { flushingRef.current = false; }
  }, [persistPending, qtRecords, user?.uid]);

  useEffect(() => {
    const uid = user?.uid;
    if (!active || !uid) { pendingRef.current = []; return; }
    let mounted = true;
    void preferences.get<PendingCommunitySubmission[]>(uid, retryPreference).then((stored) => {
      if (!mounted || user?.uid !== uid) return;
      pendingRef.current = Array.isArray(stored) ? stored.filter((item) => item && typeof item.recordId === "string" && typeof item.communityId === "string" && typeof item.dateKey === "string" && typeof item.contentId === "string" && typeof item.contentVersion === "number") : [];
      void flushCommunitySubmissions();
    }).catch(() => undefined);
    return () => { mounted = false; };
  }, [active, flushCommunitySubmissions, user?.uid]);

  useEffect(() => {
    if (!active) return;
    const subscription = AppState.addEventListener("change", (state) => { if (state === "active") void flushCommunitySubmissions(); });
    return () => subscription.remove();
  }, [active, flushCommunitySubmissions]);

  const perform = useCallback(async <T,>(work: () => Promise<T>, fallback: string): Promise<T> => {
    setErrorMessage(null);
    try { return await work(); } catch (error) { const message = personalErrorMessage(error, fallback); setErrorMessage(message); throw new Error(message); }
  }, []);

  const completeQT = useCallback(async (content: QTContent, answers: Pick<QTRecord, "reflectionAnswer" | "applicationText" | "prayerText">) => {
    if (__DEV__) console.info("[QT Complete] personal save start", { source: content.source });
    const record = await perform(() => qtRepository.save(content, answers, true), "QT를 완료하지 못했습니다.");
    setQTRecords((records) => upsertQTRecord(records, record));
    if (__DEV__) console.info("[QT Complete] personal save success", { source: record.contentSource ?? "unknown" });
    if (__DEV__) console.info("[QT Complete] garden source updated", { source: record.contentSource ?? "unknown" });
    const uid = user?.uid;
    const pending = pendingSubmissionFor(record);
    if (uid && pending) {
      if (!pendingRef.current.some((item) => item.recordId === pending.recordId && item.communityId === pending.communityId && item.dateKey === pending.dateKey)) pendingRef.current = [...pendingRef.current, pending];
      await persistPending(uid);
      void submitCompletedCommunityRecord(record, pending, uid);
    }
    if (__DEV__) console.info("[QT Complete] completion state updated", { source: content.source });
  }, [persistPending, perform, submitCompletedCommunityRecord, user?.uid]);

  const value = useMemo<QuietPrayerContextValue>(() => ({
    qtRecords, prayerRecords, errorMessage,
    qtRecord: (dateKey) => qtRecords.find((record) => record.dateKey === dateKey) ?? null,
    saveQTDraft: async (content, answers) => {
      const record = await perform(() => qtRepository.save(content, answers, false), "QT 초안을 저장하지 못했습니다.");
      setQTRecords((records) => upsertQTRecord(records, record));
    },
    completeQT,
    createPrayer: (title, userText) => perform(() => prayerRepository.create(title, userText).then(() => undefined), "기도 기록을 저장하지 못했습니다."),
    updatePrayer: (recordId, title, userText) => perform(() => prayerRepository.update(recordId, title, userText), "기도 기록을 수정하지 못했습니다."),
    deletePrayer: (recordId) => perform(() => prayerRepository.remove(recordId), "기도 기록을 삭제하지 못했습니다."),
  }), [completeQT, errorMessage, perform, prayerRecords, qtRecords]);

  return <QuietPrayerContext.Provider value={value}>{children}</QuietPrayerContext.Provider>;
}

export function useQuietPrayer(): QuietPrayerContextValue {
  const context = useContext(QuietPrayerContext);
  if (!context) throw new Error("useQuietPrayer must be used within QuietPrayerProvider.");
  return context;
}
