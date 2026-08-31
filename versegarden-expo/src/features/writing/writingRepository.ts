import { collection, doc, onSnapshot, runTransaction, serverTimestamp, setDoc, Timestamp, writeBatch } from "firebase/firestore";

import { createLocalID, firestoreDate, requireCurrentUserID, requireFirestore } from "@/features/shared/firestore";
import type { BibleVerse } from "@/features/bible/bibleTypes";

import { deterministicPlanRecordID } from "./writingPlanLogic";
import type { PlanAssignment, PlanPreview, WritingPlan, WritingRecord } from "./writingTypes";

function writingRecordsCollection() { return collection(requireFirestore(), "users", requireCurrentUserID(), "writingRecords"); }
function writingPlansCollection() { return collection(requireFirestore(), "users", requireCurrentUserID(), "writingPlans"); }

function requiredDate(value: unknown): Date | null { return firestoreDate(value); }

function parseRecord(id: string, value: Record<string, unknown>): WritingRecord | null {
  const fields = ["verseId", "book", "originalText", "userText"] as const;
  if (fields.some((field) => typeof value[field] !== "string") || typeof value.chapter !== "number" || typeof value.verse !== "number") return null;
  const date = requiredDate(value.date); const completedAt = requiredDate(value.completedAt);
  if (!date || !completedAt) return null;
  return { id, localId: typeof value.localId === "string" ? value.localId : createLocalID(), date, verseId: value.verseId as string, book: value.book as string, chapter: value.chapter as number, verse: value.verse as number, originalText: value.originalText as string, userText: value.userText as string, completedAt, sourceType: typeof value.sourceType === "string" ? value.sourceType as WritingRecord["sourceType"] : undefined, planId: typeof value.planId === "string" ? value.planId : undefined, assignmentId: typeof value.assignmentId === "string" ? value.assignmentId : undefined, planDayIndex: typeof value.planDayIndex === "number" ? value.planDayIndex : undefined };
}

function parsePlan(id: string, value: Record<string, unknown>): WritingPlan | null {
  const requiredNumbers = ["startChapter", "endChapter", "totalDays", "totalVerses", "completedDays"] as const;
  if (typeof value.title !== "string" || typeof value.book !== "string" || typeof value.statusRaw !== "string" || requiredNumbers.some((key) => typeof value[key] !== "number")) return null;
  const startDate = requiredDate(value.startDate); const endDate = requiredDate(value.endDate); const createdAt = requiredDate(value.createdAt); const updatedAt = requiredDate(value.updatedAt);
  if (!startDate || !endDate || !createdAt || !updatedAt) return null;
  return { id, localId: typeof value.localId === "string" ? value.localId : createLocalID(), title: value.title, book: value.book, startChapter: value.startChapter as number, endChapter: value.endChapter as number, startVerse: typeof value.startVerse === "number" ? value.startVerse : undefined, endVerse: typeof value.endVerse === "number" ? value.endVerse : undefined, startDate, endDate, totalDays: value.totalDays as number, totalVerses: value.totalVerses as number, completedDays: value.completedDays as number, status: value.statusRaw as WritingPlan["status"], createdAt, updatedAt };
}

function parseAssignment(planId: string, id: string, value: Record<string, unknown>): PlanAssignment | null {
  const requiredNumbers = ["dayIndex", "startChapter", "startVerse", "endChapter", "endVerse", "verseCount"] as const;
  if (typeof value.book !== "string" || typeof value.stateRaw !== "string" || requiredNumbers.some((key) => typeof value[key] !== "number")) return null;
  const date = requiredDate(value.date); const createdAt = requiredDate(value.createdAt); const updatedAt = requiredDate(value.updatedAt);
  if (!date || !createdAt || !updatedAt) return null;
  return { id, localId: typeof value.localId === "string" ? value.localId : createLocalID(), planId, planLocalId: typeof value.planLocalId === "string" ? value.planLocalId : "", dayIndex: value.dayIndex as number, date, book: value.book, startChapter: value.startChapter as number, startVerse: value.startVerse as number, endChapter: value.endChapter as number, endVerse: value.endVerse as number, verseCount: value.verseCount as number, state: value.stateRaw as PlanAssignment["state"], completedAt: firestoreDate(value.completedAt), completionRecordIds: Array.isArray(value.completionRecordIds) ? value.completionRecordIds.filter((item): item is string => typeof item === "string") : [], createdAt, updatedAt };
}

export const writingRepository = {
  subscribeRecords(onValue: (records: WritingRecord[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(writingRecordsCollection(), (snapshot) => onValue(snapshot.docs.flatMap((item) => { const record = parseRecord(item.id, item.data()); return record ? [record] : []; }).sort((left, right) => right.completedAt.getTime() - left.completedAt.getTime())), onError);
  },
  subscribePlans(onValue: (plans: WritingPlan[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(writingPlansCollection(), (snapshot) => onValue(snapshot.docs.flatMap((item) => { const plan = parsePlan(item.id, item.data()); return plan ? [plan] : []; }).sort((left, right) => right.updatedAt.getTime() - left.updatedAt.getTime())), onError);
  },
  subscribeAssignments(planId: string, onValue: (assignments: PlanAssignment[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(collection(doc(writingPlansCollection(), planId), "days"), (snapshot) => onValue(snapshot.docs.flatMap((item) => { const assignment = parseAssignment(planId, item.id, item.data()); return assignment ? [assignment] : []; }).sort((left, right) => left.dayIndex - right.dayIndex)), onError);
  },
  async saveFreeWriting(verse: BibleVerse, userText: string) {
    const userID = requireCurrentUserID(); const now = new Date(); const localId = createLocalID();
    const reference = doc(writingRecordsCollection());
    await setDoc(reference, { localId, ownerUserId: userID, date: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate())), verseId: verse.id, book: verse.book, chapter: verse.chapter, verse: verse.verse, originalText: verse.text, userText, completedAt: Timestamp.fromDate(now), sourceType: "direct", createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    return reference.id;
  },
  async createPlan(preview: PlanPreview) {
    const userID = requireCurrentUserID(); const firestore = requireFirestore(); const now = new Date(); const planReference = doc(writingPlansCollection()); const localId = createLocalID(); const batch = writeBatch(firestore);
    batch.set(planReference, { localId, ownerUserId: userID, remoteId: planReference.id, lastSyncedAt: Timestamp.fromDate(now), title: preview.title, book: preview.book, startChapter: preview.startChapter, endChapter: preview.endChapter, startDate: Timestamp.fromDate(preview.startDate), endDate: Timestamp.fromDate(preview.endDate), totalDays: preview.totalDays, totalVerses: preview.totalVerses, completedDays: 0, statusRaw: "active", createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) });
    preview.assignments.forEach((assignment) => {
      const reference = doc(collection(planReference, "days")); const assignmentLocalID = createLocalID();
      batch.set(reference, { localId: assignmentLocalID, planLocalId: localId, ownerUserId: userID, remoteId: reference.id, lastSyncedAt: Timestamp.fromDate(now), ...assignment, date: Timestamp.fromDate(assignment.date), stateRaw: "pending", completionRecordIds: [], createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) });
    });
    await batch.commit(); return planReference.id;
  },
  async savePlanWriting(verse: BibleVerse, userText: string, plan: WritingPlan, assignment: PlanAssignment, isFinalVerse: boolean) {
    const userID = requireCurrentUserID(); const firestore = requireFirestore(); const now = new Date(); const recordReference = doc(writingRecordsCollection(), deterministicPlanRecordID(plan.localId, assignment.localId, verse.id)); const assignmentReference = doc(writingPlansCollection(), plan.id, "days", assignment.id); const planReference = doc(writingPlansCollection(), plan.id);
    await runTransaction(firestore, async (transaction) => {
      const latestAssignment = await transaction.get(assignmentReference);
      const latestRecord = await transaction.get(recordReference);
      const planSnapshot = isFinalVerse ? await transaction.get(planReference) : null;
      const data = latestAssignment.data() ?? {};
      const completionRecordIds = Array.isArray(data.completionRecordIds) ? data.completionRecordIds.filter((item): item is string => typeof item === "string") : [];
      const existingRecord = latestRecord.data();
      const localId = typeof existingRecord?.localId === "string" ? existingRecord.localId : createLocalID();
      transaction.set(recordReference, { localId, ownerUserId: userID, date: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate())), verseId: verse.id, book: verse.book, chapter: verse.chapter, verse: verse.verse, originalText: verse.text, userText, completedAt: Timestamp.fromDate(now), sourceType: "plan", planId: plan.localId, assignmentId: assignment.localId, planDayIndex: assignment.dayIndex, createdAt: existingRecord?.createdAt ?? serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true });
      const nextCompletionIDs = completionRecordIds.includes(localId) ? completionRecordIds : [...completionRecordIds, localId];
      const nextState = isFinalVerse ? "completed" : (typeof data.stateRaw === "string" ? data.stateRaw : "pending");
      transaction.set(assignmentReference, { completionRecordIds: nextCompletionIDs, stateRaw: nextState, completedAt: isFinalVerse ? Timestamp.fromDate(now) : data.completedAt ?? null, updatedAt: Timestamp.fromDate(now) }, { merge: true });
      if (isFinalVerse && planSnapshot) {
        const planData = planSnapshot.data() ?? {}; const existingCompletedDays = typeof planData.completedDays === "number" ? planData.completedDays : 0; const wasComplete = data.stateRaw === "completed"; const completedDays = wasComplete ? existingCompletedDays : existingCompletedDays + 1; const totalDays = typeof planData.totalDays === "number" ? planData.totalDays : plan.totalDays;
        transaction.set(planReference, { completedDays, statusRaw: completedDays >= totalDays ? "completed" : plan.status, updatedAt: Timestamp.fromDate(now) }, { merge: true });
      }
    });
  },
};
