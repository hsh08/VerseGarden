import bibleData from "@/generated/bible_krv_full.json";

export type BibleVerse = {
  id: string;
  book: string;
  chapter: number;
  verse: number;
  testament: string;
  text: string;
  referenceText: string;
};

type BundleBibleVerse = {
  book: string;
  chapter: number;
  verse: number;
  testament: string;
  text: string;
};

const verses: BibleVerse[] = (bibleData as BundleBibleVerse[]).map((item) => ({
  ...item,
  id: `${item.book}-${item.chapter}-${item.verse}`,
  referenceText: `${item.book} ${item.chapter}:${item.verse}`
}));

export function findVerseById(id: string): BibleVerse | undefined {
  return verses.find((verse) => verse.id === id);
}

export function versesInSameChapter(startVerseId: string): BibleVerse[] {
  const startVerse = findVerseById(startVerseId);
  if (!startVerse) {
    return [];
  }

  return verses.filter(
    (verse) => verse.book === startVerse.book && verse.chapter === startVerse.chapter
  );
}

export function getVerseRange(startVerseId: string, endVerseId: string): BibleVerse[] {
  const startVerse = findVerseById(startVerseId);
  const endVerse = findVerseById(endVerseId);
  if (!startVerse || !endVerse) {
    return [];
  }

  if (startVerse.book !== endVerse.book || startVerse.chapter !== endVerse.chapter) {
    return [];
  }

  const lower = Math.min(startVerse.verse, endVerse.verse);
  const upper = Math.max(startVerse.verse, endVerse.verse);

  return verses.filter(
    (verse) =>
      verse.book === startVerse.book &&
      verse.chapter === startVerse.chapter &&
      verse.verse >= lower &&
      verse.verse <= upper
  );
}

export function isValidSameChapterRange(startVerseId: string, endVerseId: string): boolean {
  const startVerse = findVerseById(startVerseId);
  const endVerse = findVerseById(endVerseId);
  return Boolean(
    startVerse &&
      endVerse &&
      startVerse.book === endVerse.book &&
      startVerse.chapter === endVerse.chapter &&
      startVerse.verse <= endVerse.verse
  );
}

export function referenceForRange(startVerseId: string, endVerseId: string): string {
  const startVerse = findVerseById(startVerseId);
  const endVerse = findVerseById(endVerseId);
  if (!startVerse || !endVerse) {
    return "";
  }

  if (startVerse.id === endVerse.id) {
    return startVerse.referenceText;
  }

  if (startVerse.book === endVerse.book && startVerse.chapter === endVerse.chapter) {
    return `${startVerse.book} ${startVerse.chapter}:${startVerse.verse}-${endVerse.verse}`;
  }

  return `${startVerse.referenceText}-${endVerse.referenceText}`;
}

export function searchBibleVerses(query: string, limit = 30): BibleVerse[] {
  const normalizedQuery = query.trim();
  if (!normalizedQuery) {
    return [];
  }

  const compactQuery = normalizedQuery
    .replaceAll(" ", "")
    .replaceAll("장", ":")
    .replaceAll("절", "");

  return verses
    .filter((verse) => {
      const compactReference = verse.referenceText.replaceAll(" ", "");
      const compactShortReference = `${verse.book.slice(0, 1)}${verse.chapter}:${verse.verse}`;
      return (
        verse.text.includes(normalizedQuery) ||
        verse.book.includes(normalizedQuery) ||
        verse.referenceText.includes(normalizedQuery) ||
        compactReference.includes(compactQuery) ||
        compactShortReference.includes(compactQuery)
      );
    })
    .slice(0, limit);
}
