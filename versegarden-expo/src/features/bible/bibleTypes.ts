export type BibleTestament = "old" | "new";

export type BibleVerse = {
  id: string;
  book: string;
  chapter: number;
  verse: number;
  testament: BibleTestament;
  text: string;
};

export type BibleBook = {
  name: string;
  testament: BibleTestament;
  chapters: readonly number[];
};

export type BibleSearchResult = {
  verses: readonly BibleVerse[];
  hasMoreResults: boolean;
};

export type BibleVersePayload = Omit<BibleVerse, "id">;

export function createVerseId(book: string, chapter: number, verse: number): string {
  return `${book}-${chapter}-${verse}`;
}

export function createVerseReference(verse: Pick<BibleVerse, "book" | "chapter" | "verse">): string {
  return `${verse.book} ${verse.chapter}:${verse.verse}`;
}

export function parseVerseId(value: string): { book: string; chapter: number; verse: number } | null {
  const match = /^(.*)-(\d+)-(\d+)$/.exec(value);
  if (!match) return null;

  const [, book, chapterValue, verseValue] = match;
  const chapter = Number(chapterValue);
  const verse = Number(verseValue);
  if (!book || !Number.isInteger(chapter) || !Number.isInteger(verse) || chapter < 1 || verse < 1) return null;

  return { book, chapter, verse };
}
