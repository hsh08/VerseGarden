import { collection, deleteDoc, doc, onSnapshot, setDoc, Timestamp } from "firebase/firestore";

import { firestoreDate, requireCurrentUserID, requireFirestore } from "@/features/shared/firestore";

export type LikedVerse = { verseId: string; createdAt: Date };

function likedVersesCollection() {
  const userID = requireCurrentUserID();
  return collection(requireFirestore(), "users", userID, "likedVerses");
}

export const likedVerseRepository = {
  subscribe(onValue: (records: LikedVerse[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(likedVersesCollection(), (snapshot) => {
      const records = snapshot.docs.flatMap((item) => {
        const verseId = typeof item.data().verseId === "string" ? item.data().verseId.trim() : item.id;
        if (!verseId) return [];
        const createdAt = firestoreDate(item.data().createdAt);
        return createdAt ? [{ verseId, createdAt }] : [];
      }).sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime());
      onValue([...new Map(records.map((record) => [record.verseId, record])).values()]);
    }, onError);
  },
  async like(verseId: string) {
    const trimmedVerseID = verseId.trim();
    if (!trimmedVerseID) throw new Error("invalid-verse");
    await setDoc(doc(likedVersesCollection(), trimmedVerseID), { verseId: trimmedVerseID, createdAt: Timestamp.fromDate(new Date()) }, { merge: true });
  },
  async unlike(verseId: string) {
    const trimmedVerseID = verseId.trim();
    if (!trimmedVerseID) throw new Error("invalid-verse");
    await deleteDoc(doc(likedVersesCollection(), trimmedVerseID));
  },
};
