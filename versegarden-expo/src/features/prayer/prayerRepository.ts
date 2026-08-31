import { collection, deleteDoc, doc, onSnapshot, serverTimestamp, setDoc, Timestamp, writeBatch } from "firebase/firestore";

import { createLocalID, firestoreDate, requireCurrentUserID, requireFirestore } from "@/features/shared/firestore";

import type { PrayerRecord } from "./prayerTypes";

function recordsCollection() { return collection(requireFirestore(), "users", requireCurrentUserID(), "prayerWritingRecords"); }
function templatesCollection() { return collection(requireFirestore(), "users", requireCurrentUserID(), "prayers"); }

function recordFromDocument(id: string, value: Record<string, unknown>): PrayerRecord | null {
  const date = firestoreDate(value.date); const completedAt = firestoreDate(value.completedAt); const createdAt = firestoreDate(value.createdAt); const updatedAt = firestoreDate(value.updatedAt);
  if (!date || !completedAt || !createdAt || !updatedAt || typeof value.sourceType !== "string" || typeof value.titleSnapshot !== "string" || typeof value.originalText !== "string" || typeof value.userText !== "string") return null;
  const sourceType = value.sourceType === "userPrayer" || value.sourceType === "defaultPrayer" || value.sourceType === "freeformPrayer" ? value.sourceType : "freeformPrayer";
  return { id, localId: typeof value.localId === "string" ? value.localId : createLocalID(), ownerUserId: typeof value.ownerUserId === "string" ? value.ownerUserId : requireCurrentUserID(), templateLocalId: typeof value.templateLocalId === "string" ? value.templateLocalId : undefined, templateRemoteId: typeof value.templateRemoteId === "string" ? value.templateRemoteId : undefined, sourceType, titleSnapshot: value.titleSnapshot, originalText: value.originalText, userText: value.userText, date, completedAt, createdAt, updatedAt };
}

export const prayerRepository = {
  subscribe(onValue: (records: PrayerRecord[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(recordsCollection(), (snapshot) => onValue(snapshot.docs.flatMap((item) => { const record = recordFromDocument(item.id, item.data()); return record ? [record] : []; }).sort((left, right) => right.completedAt.getTime() - left.completedAt.getTime())), onError);
  },
  async create(title: string, userText: string) {
    const firestore = requireFirestore(); const ownerUserId = requireCurrentUserID(); const now = new Date(); const templateLocalId = createLocalID(); const templateReference = doc(templatesCollection()); const recordReference = doc(recordsCollection()); const recordLocalId = createLocalID(); const batch = writeBatch(firestore);
    batch.set(templateReference, { title, bodyText: userText, category: null, ownerUserId, localId: templateLocalId, remoteId: templateReference.id, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now), lastSyncedAt: serverTimestamp(), isArchived: false });
    batch.set(recordReference, { ownerUserId, localId: recordLocalId, remoteId: recordReference.id, templateLocalId, templateRemoteId: templateReference.id, sourceType: "freeformPrayer", titleSnapshot: title, originalText: "", userText, date: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate())), completedAt: Timestamp.fromDate(now), createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now), lastSyncedAt: serverTimestamp() });
    await batch.commit();
    return recordReference.id;
  },
  async update(recordId: string, title: string, userText: string) {
    await setDoc(doc(recordsCollection(), recordId), { titleSnapshot: title, originalText: "", userText, updatedAt: serverTimestamp(), lastSyncedAt: serverTimestamp() }, { merge: true });
  },
  async remove(recordId: string) { await deleteDoc(doc(recordsCollection(), recordId)); },
};
