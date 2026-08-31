import { addDoc, collection, deleteDoc, doc, getDoc, getDocs, onSnapshot, serverTimestamp, setDoc, Timestamp, writeBatch } from "firebase/firestore";

import { createLocalID, firestoreDate, requireCurrentUserID, requireFirestore } from "@/features/shared/firestore";
import type { BibleVerse } from "@/features/bible/bibleTypes";

export type VerseList = { id: string; title: string; memo: string; ownerUserId: string; localId: string; createdAt: Date; updatedAt: Date };
export type VerseListItem = { id: string; listId: string; localId: string; book: string; chapter: number; verse: number; verseId: string; createdAt: Date; updatedAt: Date };

function listsCollection() {
  const userID = requireCurrentUserID();
  return collection(requireFirestore(), "users", userID, "verseLists");
}

function listFromDocument(id: string, value: Record<string, unknown>): VerseList | null {
  const title = typeof value.title === "string" ? value.title.trim() : "";
  const ownerUserId = typeof value.ownerUserId === "string" ? value.ownerUserId : "";
  const createdAt = firestoreDate(value.createdAt);
  const updatedAt = firestoreDate(value.updatedAt) ?? createdAt;
  if (!title || !ownerUserId || !createdAt || !updatedAt) return null;
  return { id, title, memo: typeof value.memo === "string" ? value.memo : "", ownerUserId, localId: typeof value.localId === "string" ? value.localId : createLocalID(), createdAt, updatedAt };
}

function itemFromDocument(listId: string, id: string, value: Record<string, unknown>): VerseListItem | null {
  const book = typeof value.book === "string" ? value.book : "";
  const chapter = typeof value.chapter === "number" ? value.chapter : 0;
  const verse = typeof value.verse === "number" ? value.verse : 0;
  const createdAt = firestoreDate(value.createdAt);
  const updatedAt = firestoreDate(value.updatedAt);
  if (!book || chapter < 1 || verse < 1 || !createdAt || !updatedAt) return null;
  return { id, listId, localId: typeof value.localId === "string" ? value.localId : createLocalID(), book, chapter, verse, verseId: `${book}-${chapter}-${verse}`, createdAt, updatedAt };
}

export const verseListRepository = {
  subscribeLists(onValue: (lists: VerseList[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(listsCollection(), (snapshot) => {
      onValue(snapshot.docs.flatMap((item) => {
        const list = listFromDocument(item.id, item.data());
        return list ? [list] : [];
      }).sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime()));
    }, onError);
  },
  async createList(title: string, memo: string) {
    const ownerUserId = requireCurrentUserID();
    const now = new Date();
    const localId = createLocalID();
    const reference = await addDoc(listsCollection(), { title: title.trim(), memo: memo.trim(), createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now), ownerUserId, localId, lastSyncedAt: serverTimestamp() });
    return reference.id;
  },
  async updateList(listId: string, title: string, memo: string) {
    await setDoc(doc(listsCollection(), listId), { title: title.trim(), memo: memo.trim(), updatedAt: serverTimestamp(), lastSyncedAt: serverTimestamp() }, { merge: true });
  },
  async deleteList(listId: string) {
    const firestore = requireFirestore();
    const listDocument = doc(listsCollection(), listId);
    const items = await getDocs(collection(listDocument, "items"));
    const batch = writeBatch(firestore);
    items.docs.forEach((item) => batch.delete(item.ref));
    batch.delete(listDocument);
    await batch.commit();
  },
  subscribeItems(listId: string, onValue: (items: VerseListItem[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(collection(doc(listsCollection(), listId), "items"), (snapshot) => {
      const unique = new Map<string, VerseListItem>();
      snapshot.docs.forEach((item) => {
        const decoded = itemFromDocument(listId, item.id, item.data());
        if (decoded && !unique.has(decoded.verseId)) unique.set(decoded.verseId, decoded);
      });
      onValue([...unique.values()].sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime()));
    }, onError);
  },
  async addVerse(listId: string, verse: BibleVerse) {
    const ownerUserId = requireCurrentUserID();
    const listDocument = doc(listsCollection(), listId);
    const listSnapshot = await getDoc(listDocument);
    if (!listSnapshot.exists()) throw new Error("missing-list");
    const listLocalId = typeof listSnapshot.data()?.localId === "string" ? listSnapshot.data().localId : createLocalID();
    const items = collection(listDocument, "items");
    const existing = await getDocs(items);
    const duplicate = existing.docs.some((item) => item.data().book === verse.book && item.data().chapter === verse.chapter && item.data().verse === verse.verse);
    if (duplicate) return false;
    const now = new Date();
    const reference = doc(items);
    await setDoc(reference, { ownerUserId, listLocalId, localId: createLocalID(), remoteDocumentId: reference.id, book: verse.book, chapter: verse.chapter, verse: verse.verse, verseText: verse.text, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now), lastSyncedAt: serverTimestamp() });
    return true;
  },
  async removeVerse(listId: string, itemId: string) {
    await deleteDoc(doc(listsCollection(), listId, "items", itemId));
  },
};
