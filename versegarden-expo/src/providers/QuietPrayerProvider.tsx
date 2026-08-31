import type { PropsWithChildren } from "react";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

import type { QTContent, QTRecord } from "@/features/qt/qtTypes";
import { qtRepository } from "@/features/qt/qtRepository";
import { prayerRepository } from "@/features/prayer/prayerRepository";
import type { PrayerRecord } from "@/features/prayer/prayerTypes";
import { personalErrorMessage } from "@/features/shared/firestore";

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

export function QuietPrayerProvider({ children }: PropsWithChildren) {
  const { phase } = useAuthSession();
  const [qtRecords, setQTRecords] = useState<QTRecord[]>([]);
  const [prayerRecords, setPrayerRecords] = useState<PrayerRecord[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
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

  const perform = useCallback(async (work: () => Promise<void>, fallback: string) => {
    setErrorMessage(null);
    try { await work(); } catch (error) { const message = personalErrorMessage(error, fallback); setErrorMessage(message); throw new Error(message); }
  }, []);

  const value = useMemo<QuietPrayerContextValue>(() => ({
    qtRecords, prayerRecords, errorMessage,
    qtRecord: (dateKey) => qtRecords.find((record) => record.dateKey === dateKey) ?? null,
    saveQTDraft: (content, answers) => perform(() => qtRepository.save(content, answers, false), "QT 초안을 저장하지 못했습니다."),
    completeQT: (content, answers) => perform(() => qtRepository.save(content, answers, true), "QT를 완료하지 못했습니다."),
    createPrayer: (title, userText) => perform(() => prayerRepository.create(title, userText).then(() => undefined), "기도 기록을 저장하지 못했습니다."),
    updatePrayer: (recordId, title, userText) => perform(() => prayerRepository.update(recordId, title, userText), "기도 기록을 수정하지 못했습니다."),
    deletePrayer: (recordId) => perform(() => prayerRepository.remove(recordId), "기도 기록을 삭제하지 못했습니다."),
  }), [errorMessage, perform, prayerRecords, qtRecords]);

  return <QuietPrayerContext.Provider value={value}>{children}</QuietPrayerContext.Provider>;
}

export function useQuietPrayer(): QuietPrayerContextValue {
  const context = useContext(QuietPrayerContext);
  if (!context) throw new Error("useQuietPrayer must be used within QuietPrayerProvider.");
  return context;
}
