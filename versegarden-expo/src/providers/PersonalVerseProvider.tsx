import type { PropsWithChildren } from "react";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

import type { BibleVerse } from "@/features/bible/bibleTypes";
import { likedVerseRepository, type LikedVerse } from "@/features/likes/likedVerseRepository";
import { personalErrorMessage } from "@/features/shared/firestore";
import { verseListRepository, type VerseList, type VerseListItem } from "@/features/verseLists/verseListRepository";
import { writingRepository } from "@/features/writing/writingRepository";
import type { PlanAssignment, PlanPreview, WritingPlan, WritingRecord } from "@/features/writing/writingTypes";

import { useAuthSession } from "./AuthSessionProvider";

type PersonalVerseContextValue = {
  likes: readonly LikedVerse[];
  lists: readonly VerseList[];
  records: readonly WritingRecord[];
  plans: readonly WritingPlan[];
  assignmentsByPlan: Readonly<Record<string, readonly PlanAssignment[]>>;
  isLoading: boolean;
  errorMessage: string | null;
  isLiked(verseId: string): boolean;
  toggleLike(verseId: string): Promise<void>;
  createList(title: string, memo: string): Promise<string>;
  updateList(listId: string, title: string, memo: string): Promise<void>;
  deleteList(listId: string): Promise<void>;
  subscribeListItems(listId: string, onValue: (items: VerseListItem[]) => void, onError?: () => void): () => void;
  addVerseToList(listId: string, verse: BibleVerse): Promise<boolean>;
  removeVerseFromList(listId: string, itemId: string): Promise<void>;
  saveFreeWriting(verse: BibleVerse, userText: string): Promise<void>;
  createPlan(preview: PlanPreview): Promise<string>;
  savePlanWriting(verse: BibleVerse, userText: string, plan: WritingPlan, assignment: PlanAssignment, isFinalVerse: boolean): Promise<void>;
};

const PersonalVerseContext = createContext<PersonalVerseContextValue | null>(null);

export function PersonalVerseProvider({ children }: PropsWithChildren) {
  const { phase } = useAuthSession();
  const [likes, setLikes] = useState<LikedVerse[]>([]);
  const [lists, setLists] = useState<VerseList[]>([]);
  const [records, setRecords] = useState<WritingRecord[]>([]);
  const [plans, setPlans] = useState<WritingPlan[]>([]);
  const [assignmentsByPlan, setAssignmentsByPlan] = useState<Record<string, readonly PlanAssignment[]>>({});
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const active = phase === "ready";

  useEffect(() => {
    if (!active) {
      const clear = setTimeout(() => { setLikes([]); setLists([]); setRecords([]); setPlans([]); setAssignmentsByPlan({}); setErrorMessage(null); setIsLoading(false); }, 0);
      return () => clearTimeout(clear);
    }

    let mounted = true;
    const assignmentUnsubscribes = new Map<string, () => void>();
    const onError = (fallback: string) => (error: unknown) => { if (mounted) setErrorMessage(personalErrorMessage(error, fallback)); };
    const likesUnsubscribe = likedVerseRepository.subscribe((value) => { if (mounted) setLikes(value); }, onError("저장한 말씀을 불러오지 못했습니다."));
    const listsUnsubscribe = verseListRepository.subscribeLists((value) => { if (mounted) setLists(value); }, onError("말씀 리스트를 불러오지 못했습니다."));
    const recordsUnsubscribe = writingRepository.subscribeRecords((value) => { if (mounted) setRecords(value); }, onError("필사 기록을 불러오지 못했습니다."));
    const plansUnsubscribe = writingRepository.subscribePlans((value) => {
      if (!mounted) return;
      setPlans(value);
      const activeIDs = new Set(value.map((plan) => plan.id));
      assignmentUnsubscribes.forEach((unsubscribe, planID) => {
        if (!activeIDs.has(planID)) { unsubscribe(); assignmentUnsubscribes.delete(planID); }
      });
      value.forEach((plan) => {
        if (assignmentUnsubscribes.has(plan.id)) return;
        assignmentUnsubscribes.set(plan.id, writingRepository.subscribeAssignments(plan.id, (assignments) => {
          if (mounted) setAssignmentsByPlan((current) => ({ ...current, [plan.id]: assignments }));
        }, onError("필사 플랜 분량을 불러오지 못했습니다.")));
      });
      setIsLoading(false);
    }, onError("필사 플랜을 불러오지 못했습니다."));
    const initialLoad = setTimeout(() => { if (mounted) setIsLoading(true); }, 0);

    return () => {
      mounted = false;
      clearTimeout(initialLoad);
      likesUnsubscribe(); listsUnsubscribe(); recordsUnsubscribe(); plansUnsubscribe();
      assignmentUnsubscribes.forEach((unsubscribe) => unsubscribe());
    };
  }, [active]);

  const perform = useCallback(async <T,>(work: () => Promise<T>, fallback: string): Promise<T> => {
    setErrorMessage(null);
    try { return await work(); } catch (error) { const message = personalErrorMessage(error, fallback); setErrorMessage(message); throw new Error(message); }
  }, []);

  const value = useMemo<PersonalVerseContextValue>(() => ({
    likes, lists, records, plans, assignmentsByPlan, isLoading, errorMessage,
    isLiked: (verseId) => likes.some((item) => item.verseId === verseId),
    toggleLike: async (verseId) => {
      const existing = likes.find((item) => item.verseId === verseId);
      const before = likes;
      setLikes(existing ? likes.filter((item) => item.verseId !== verseId) : [{ verseId, createdAt: new Date() }, ...likes]);
      try { await perform(() => existing ? likedVerseRepository.unlike(verseId) : likedVerseRepository.like(verseId), "말씀 저장 상태를 바꾸지 못했습니다."); } catch { setLikes(before); }
    },
    createList: (title, memo) => perform(() => verseListRepository.createList(title, memo), "리스트를 만들지 못했습니다."),
    updateList: (listId, title, memo) => perform(() => verseListRepository.updateList(listId, title, memo), "리스트를 수정하지 못했습니다."),
    deleteList: (listId) => perform(() => verseListRepository.deleteList(listId), "리스트를 삭제하지 못했습니다."),
    subscribeListItems: (listId, onValue, onError) => verseListRepository.subscribeItems(listId, onValue, () => { setErrorMessage("리스트 구절을 불러오지 못했습니다."); onError?.(); }),
    addVerseToList: (listId, verse) => perform(() => verseListRepository.addVerse(listId, verse), "리스트에 말씀을 추가하지 못했습니다."),
    removeVerseFromList: (listId, itemId) => perform(() => verseListRepository.removeVerse(listId, itemId), "리스트에서 말씀을 제거하지 못했습니다."),
    saveFreeWriting: (verse, userText) => perform(() => writingRepository.saveFreeWriting(verse, userText).then(() => undefined), "필사를 저장하지 못했습니다."),
    createPlan: (preview) => perform(() => writingRepository.createPlan(preview), "필사 플랜을 만들지 못했습니다."),
    savePlanWriting: (verse, userText, plan, assignment, isFinalVerse) => perform(() => writingRepository.savePlanWriting(verse, userText, plan, assignment, isFinalVerse), "필사를 저장하지 못했습니다."),
  }), [assignmentsByPlan, errorMessage, isLoading, likes, lists, perform, plans, records]);

  return <PersonalVerseContext.Provider value={value}>{children}</PersonalVerseContext.Provider>;
}

export function usePersonalVerse(): PersonalVerseContextValue {
  const context = useContext(PersonalVerseContext);
  if (!context) throw new Error("usePersonalVerse must be used within PersonalVerseProvider.");
  return context;
}
