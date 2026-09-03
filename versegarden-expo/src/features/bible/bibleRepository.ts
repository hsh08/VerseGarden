import rawBibleData from "../../../assets/bible/bible_krv_full.json";

import { traceStartup } from "@/services/diagnostics/startupTimeline";

import {
  createVerseId,
  type BibleBook,
  type BibleSearchResult,
  type BibleTestament,
  type BibleVerse,
  type BibleVersePayload,
} from "./bibleTypes";

const rawVerses = rawBibleData as BibleVersePayload[];

export class BibleRepository {
  private readonly verses: readonly BibleVerse[];
  private readonly versesByID: ReadonlyMap<string, BibleVerse>;
  private readonly books: readonly BibleBook[];
  private readonly versesByBookChapter: ReadonlyMap<string, readonly BibleVerse[]>;
  private readonly booksBySearchAlias: ReadonlyMap<string, readonly BibleBook[]>;
  private hasCompletedFirstTextSearch = false;

  constructor(payload: readonly BibleVersePayload[]) {
    const startedAt = Date.now();
    const versesStartedAt = Date.now();
    this.verses = payload.map((item) => ({ ...item, id: createVerseId(item.book, item.chapter, item.verse) }));
    traceStartup("Bible browse verses prepared", { elapsedMilliseconds: Date.now() - versesStartedAt, verseCount: this.verses.length });

    const identifiersStartedAt = Date.now();
    this.versesByID = new Map(this.verses.map((verse) => [verse.id, verse]));
    traceStartup("Bible verse ID index prepared", { elapsedMilliseconds: Date.now() - identifiersStartedAt, verseCount: this.versesByID.size });

    const browseIndexStartedAt = Date.now();
    const books = new Map<string, { testament: BibleTestament; chapters: Set<number> }>();
    const versesByBookChapter = new Map<string, BibleVerse[]>();
    for (const verse of this.verses) {
      const book = books.get(verse.book) ?? { testament: verse.testament, chapters: new Set<number>() };
      book.chapters.add(verse.chapter);
      books.set(verse.book, book);

      const chapterKey = this.chapterKey(verse.book, verse.chapter);
      const chapterVerses = versesByBookChapter.get(chapterKey) ?? [];
      chapterVerses.push(verse);
      versesByBookChapter.set(chapterKey, chapterVerses);
    }
    this.books = [...books.entries()].map(([name, book]) => ({ name, testament: book.testament, chapters: [...book.chapters] }));
    this.versesByBookChapter = versesByBookChapter;
    this.booksBySearchAlias = buildBookAliases(this.books);
    traceStartup("Bible browse book and chapter index prepared", { bookCount: this.books.length, elapsedMilliseconds: Date.now() - browseIndexStartedAt });
    traceStartup("Bible browse repository constructed", { elapsedMilliseconds: Date.now() - startedAt, verseCount: this.verses.length });
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

  async search(query: string, limit: number): Promise<BibleSearchResult> {
    const startedAt = Date.now();
    const normalizedQuery = normalize(query);
    const compactQuery = compactReference(query);
    if (!normalizedQuery || limit < 1) return { verses: [], hasMoreResults: false };

    const structured = this.structuredReferenceSearch(compactQuery, limit);
    if (structured) {
      if (__DEV__) console.info("[Search Cold] structured result ready", { elapsedMilliseconds: Date.now() - startedAt, resultCount: structured.verses.length });
      return structured;
    }

    const isColdTextSearch = !this.hasCompletedFirstTextSearch;
    if (__DEV__ && isColdTextSearch) console.info("[Search Cold] text scan started", { queryLength: normalizedQuery.length, verseCount: this.verses.length });
    const result = limitVerseResults(this.verses.filter((verse) => verse.text.includes(normalizedQuery)), limit);
    this.hasCompletedFirstTextSearch = true;
    if (__DEV__) console.info(isColdTextSearch ? "[Search Cold] first text result ready" : "[Search] text result ready", { elapsedMilliseconds: Date.now() - startedAt, resultCount: result.verses.length });
    return result;
  }

  private structuredReferenceSearch(compactQuery: string, limit: number): BibleSearchResult | null {
    const alias = [...this.booksBySearchAlias.keys()].sort((left, right) => right.length - left.length).find((value) => compactQuery.startsWith(value));
    if (!alias) return null;

    const books = this.booksBySearchAlias.get(alias);
    const suffix = compactQuery.slice(alias.length);
    if (!books || (suffix.length > 0 && !/^\d/.test(suffix))) return null;
    if (!suffix) return limitVerseResults(books.flatMap((book) => book.chapters.flatMap((chapter) => this.getVerses(book.name, chapter))), limit);

    const [chapterValue, verseValue] = suffix.split(":", 2);
    const chapter = Number(chapterValue);
    if (!Number.isInteger(chapter)) return null;
    const verse = verseValue === undefined ? null : Number(verseValue);
    if (verseValue !== undefined && !Number.isInteger(verse)) return null;

    return limitVerseResults(books.flatMap((book) => this.getVerses(book.name, chapter).filter((candidate) => verse === null || candidate.verse === verse)), limit);
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
        traceStartup("Bible repository construction started", { verseCount: rawVerses.length });
        cachedRepository = new BibleRepository(rawVerses);
        traceStartup("Bible repository construction completed", { verseCount: rawVerses.length });
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

function buildBookAliases(books: readonly BibleBook[]): ReadonlyMap<string, readonly BibleBook[]> {
  const aliases = new Map<string, BibleBook[]>();
  for (const book of books) {
    const normalizedBook = normalize(book.name);
    for (const alias of [normalizedBook, normalizedBook.slice(0, 1)]) {
      const candidates = aliases.get(alias) ?? [];
      candidates.push(book);
      aliases.set(alias, candidates);
    }
  }
  return aliases;
}

function limitVerseResults(verses: readonly BibleVerse[], limit: number): BibleSearchResult {
  const visibleVerses = verses.slice(0, limit);
  return { verses: visibleVerses, hasMoreResults: verses.length > visibleVerses.length };
}
