import rawBibleData from "../../../assets/bible/bible_krv_full.json";

import {
  createVerseId,
  type BibleBook,
  type BibleSearchResult,
  type BibleTestament,
  type BibleVerse,
  type BibleVersePayload,
} from "./bibleTypes";

const rawVerses = rawBibleData as BibleVersePayload[];

type SearchEntry = {
  verse: BibleVerse;
  normalizedReference: string;
  normalizedShortReference: string;
  normalizedText: string;
};

export class BibleRepository {
  private readonly verses: readonly BibleVerse[];
  private readonly versesByID: ReadonlyMap<string, BibleVerse>;
  private readonly books: readonly BibleBook[];
  private readonly versesByBookChapter: ReadonlyMap<string, readonly BibleVerse[]>;
  private readonly entries: readonly SearchEntry[];
  private readonly entriesByBook: ReadonlyMap<string, readonly SearchEntry[]>;
  private readonly bookAliases: ReadonlyMap<string, readonly string[]>;

  constructor(payload: readonly BibleVersePayload[]) {
    this.verses = payload.map((item) => ({ ...item, id: createVerseId(item.book, item.chapter, item.verse) }));
    this.versesByID = new Map(this.verses.map((verse) => [verse.id, verse]));

    const books = new Map<string, { testament: BibleTestament; chapters: number[] }>();
    const versesByBookChapter = new Map<string, BibleVerse[]>();
    for (const verse of this.verses) {
      const book = books.get(verse.book) ?? { testament: verse.testament, chapters: [] };
      if (!book.chapters.includes(verse.chapter)) book.chapters.push(verse.chapter);
      books.set(verse.book, book);

      const chapterKey = this.chapterKey(verse.book, verse.chapter);
      const chapterVerses = versesByBookChapter.get(chapterKey) ?? [];
      chapterVerses.push(verse);
      versesByBookChapter.set(chapterKey, chapterVerses);
    }
    this.books = [...books.entries()].map(([name, book]) => ({ name, testament: book.testament, chapters: book.chapters }));
    this.versesByBookChapter = versesByBookChapter;

    this.entries = this.verses.map((verse) => ({
      verse,
      normalizedReference: compactReference(`${verse.book}${verse.chapter}:${verse.verse}`),
      normalizedShortReference: compactReference(`${verse.book.slice(0, 1)}${verse.chapter}:${verse.verse}`),
      normalizedText: normalize(verse.text),
    }));

    const entriesByBook = new Map<string, SearchEntry[]>();
    for (const entry of this.entries) {
      const key = normalize(entry.verse.book);
      const bookEntries = entriesByBook.get(key) ?? [];
      bookEntries.push(entry);
      entriesByBook.set(key, bookEntries);
    }
    this.entriesByBook = entriesByBook;

    const aliases = new Map<string, Set<string>>();
    for (const book of entriesByBook.keys()) {
      const firstCharacter = book.slice(0, 1);
      aliases.set(book, new Set([...(aliases.get(book) ?? []), book]));
      aliases.set(firstCharacter, new Set([...(aliases.get(firstCharacter) ?? []), book]));
    }
    this.bookAliases = new Map([...aliases.entries()].map(([alias, values]) => [alias, [...values].sort((left, right) => right.length - left.length)]));
  }

  getBooks(testament?: BibleTestament): readonly BibleBook[] {
    return testament ? this.books.filter((book) => book.testament === testament) : this.books;
  }

  getChapters(book: string): readonly number[] {
    return this.books.find((item) => item.name === book)?.chapters ?? [];
  }

  getVerses(book: string, chapter: number): readonly BibleVerse[] {
    return this.versesByBookChapter.get(this.chapterKey(book, chapter)) ?? [];
  }

  getVerse(id: string): BibleVerse | null {
    return this.versesByID.get(id) ?? null;
  }

  search(query: string, limit: number): BibleSearchResult {
    const normalizedQuery = normalize(query);
    const compactQuery = compactReference(query);
    if (!normalizedQuery || limit < 1) return { verses: [], hasMoreResults: false };

    const structured = this.structuredReferenceSearch(compactQuery, limit);
    if (structured) return structured;

    return limitResults(
      this.entries.filter((entry) => entry.normalizedText.includes(normalizedQuery)
        || entry.normalizedReference.includes(compactQuery)
        || entry.normalizedShortReference.includes(compactQuery)),
      limit,
    );
  }

  private structuredReferenceSearch(compactQuery: string, limit: number): BibleSearchResult | null {
    const alias = [...this.bookAliases.keys()].sort((left, right) => right.length - left.length).find((value) => compactQuery.startsWith(value));
    if (!alias) return null;

    const books = this.bookAliases.get(alias);
    const suffix = compactQuery.slice(alias.length);
    if (!books || (suffix.length > 0 && !/^\d/.test(suffix))) return null;

    const candidates = books.flatMap((book) => this.entriesByBook.get(book) ?? []);
    if (!suffix) return limitResults(candidates, limit);

    const [chapterValue, verseValue] = suffix.split(":", 2);
    const chapter = Number(chapterValue);
    if (!Number.isInteger(chapter)) return null;
    const verse = verseValue === undefined ? null : Number(verseValue);
    if (verseValue !== undefined && !Number.isInteger(verse)) return null;

    return limitResults(candidates.filter((entry) => entry.verse.chapter === chapter && (verse === null || entry.verse.verse === verse)), limit);
  }

  private chapterKey(book: string, chapter: number): string {
    return `${book}\u0000${chapter}`;
  }
}

let cachedRepository: BibleRepository | null = null;
let loadingRepository: Promise<BibleRepository> | null = null;

export function loadBibleRepository(): Promise<BibleRepository> {
  if (cachedRepository) return Promise.resolve(cachedRepository);
  if (!loadingRepository) {
    loadingRepository = new Promise((resolve) => {
      setTimeout(() => {
        cachedRepository = new BibleRepository(rawVerses);
        resolve(cachedRepository);
      }, 0);
    });
  }
  return loadingRepository;
}

export function normalize(value: string): string {
  return value.trim().toLocaleLowerCase("ko-KR");
}

export function compactReference(value: string): string {
  return normalize(value).replace(/\s+/g, "").replace(/장/g, ":").replace(/절/g, "");
}

function limitResults(entries: readonly SearchEntry[], limit: number): BibleSearchResult {
  const visibleEntries = entries.slice(0, limit);
  return { verses: visibleEntries.map((entry) => entry.verse), hasMoreResults: entries.length > visibleEntries.length };
}
