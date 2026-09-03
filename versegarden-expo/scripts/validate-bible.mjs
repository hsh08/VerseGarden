import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";
import { fileURLToPath } from "node:url";

const dataURL = new URL("../assets/bible/bible_krv_full.json", import.meta.url);
const startedAt = performance.now();
const verses = JSON.parse(await readFile(fileURLToPath(dataURL), "utf8"));
const dataLoadMilliseconds = performance.now() - startedAt;

const createVerseId = (book, chapter, verse) => `${book}-${chapter}-${verse}`;
const parseVerseId = (value) => {
  const match = /^(.*)-(\d+)-(\d+)$/.exec(value);
  if (!match) return null;
  const [, book, chapterValue, verseValue] = match;
  const chapter = Number(chapterValue);
  const verse = Number(verseValue);
  return book && Number.isInteger(chapter) && chapter > 0 && Number.isInteger(verse) && verse > 0 ? { book, chapter, verse } : null;
};
const normalize = (value) => value.trim().toLocaleLowerCase("ko-KR");
const compactReference = (value) => normalize(value).replace(/\s+/g, "").replace(/장/g, ":").replace(/절/g, "");
const chapterKey = (book, chapter) => `${book}\u0000${chapter}`;

const browseStartedAt = performance.now();
const versesWithID = verses.map((verse) => ({ ...verse, id: createVerseId(verse.book, verse.chapter, verse.verse) }));
const versesByID = new Map(versesWithID.map((verse) => [verse.id, verse]));
const books = new Map();
const versesByBookChapter = new Map();
for (const verse of versesWithID) {
  const book = books.get(verse.book) ?? { name: verse.book, testament: verse.testament, chapters: new Set() };
  book.chapters.add(verse.chapter);
  books.set(verse.book, book);
  const key = chapterKey(verse.book, verse.chapter);
  const chapterVerses = versesByBookChapter.get(key) ?? [];
  chapterVerses.push(verse);
  versesByBookChapter.set(key, chapterVerses);
}
const bookList = [...books.values()].map((book) => ({ ...book, chapters: [...book.chapters] }));
const bookAliases = new Map();
for (const book of bookList) {
  const normalizedBook = normalize(book.name);
  for (const alias of [normalizedBook, normalizedBook.slice(0, 1)]) {
    const candidates = bookAliases.get(alias) ?? [];
    candidates.push(book);
    bookAliases.set(alias, candidates);
  }
}
const browseIndexMilliseconds = performance.now() - browseStartedAt;

function limitResults(items, limit) {
  const verses = items.slice(0, limit);
  return { verses, hasMoreResults: items.length > verses.length };
}

function structuredReferenceSearch(compactQuery, limit) {
  const alias = [...bookAliases.keys()].sort((left, right) => right.length - left.length).find((value) => compactQuery.startsWith(value));
  if (!alias) return null;
  const matchingBooks = bookAliases.get(alias);
  const suffix = compactQuery.slice(alias.length);
  if (!matchingBooks || (suffix.length > 0 && !/^\d/.test(suffix))) return null;
  if (!suffix) return limitResults(matchingBooks.flatMap((book) => book.chapters.flatMap((chapter) => versesByBookChapter.get(chapterKey(book.name, chapter)) ?? [])), limit);

  const [chapterValue, verseValue] = suffix.split(":", 2);
  const chapter = Number(chapterValue);
  const verse = verseValue === undefined ? null : Number(verseValue);
  if (!Number.isInteger(chapter) || (verseValue !== undefined && !Number.isInteger(verse))) return null;
  return limitResults(matchingBooks.flatMap((book) => (versesByBookChapter.get(chapterKey(book.name, chapter)) ?? []).filter((candidate) => verse === null || candidate.verse === verse)), limit);
}

function search(query, limit = 12) {
  const normalizedQuery = normalize(query);
  const compactQuery = compactReference(query);
  if (!normalizedQuery || limit < 1) return { verses: [], hasMoreResults: false };
  return structuredReferenceSearch(compactQuery, limit) ?? limitResults(versesWithID.filter((verse) => verse.text.includes(normalizedQuery)), limit);
}

assert.equal(verses.length, 31089, "The bundled dataset verse count changed unexpectedly.");
assert.equal(createVerseId("창세기", 1, 1), "창세기-1-1");
assert.deepEqual(parseVerseId("마태복음-11-28"), { book: "마태복음", chapter: 11, verse: 28 });
assert.equal(parseVerseId("malformed"), null);
assert.equal(versesByID.size, versesWithID.length, "Verse IDs must be unique.");
assert.equal(versesWithID.every((verse, index) => verse.id === createVerseId(verses[index].book, verses[index].chapter, verses[index].verse) && verse.text === verses[index].text), true, "Stable IDs and source text must remain canonical.");
assert.equal(search("창세기 1:1").verses[0]?.id, "창세기-1-1");
assert.equal(search("마태복음 11:28").verses[0]?.id, "마태복음-11-28");
assert.equal(search("창세기 1").verses.every((verse) => verse.book === "창세기" && verse.chapter === 1), true);
assert.equal(search("창 세 기 1 장 1 절").verses[0]?.id, "창세기-1-1");
assert.equal(search("사랑", 1).verses.length, 1);
assert.equal(search("사랑", 1).hasMoreResults, true);

const benchmark = (query) => {
  const started = performance.now();
  const result = search(query);
  return { milliseconds: Number((performance.now() - started).toFixed(3)), resultCount: result.verses.length, hasMoreResults: result.hasMoreResults };
};

console.log(JSON.stringify({
  verseCount: verses.length,
  dataLoadMilliseconds: Number(dataLoadMilliseconds.toFixed(3)),
  browseIndexMilliseconds: Number(browseIndexMilliseconds.toFixed(3)),
  derivedSearchAsset: "none (canonical source text is searched directly)",
  benchmarks: Object.fromEntries(["사랑", "예수", "요한", "창세기", "창세기 1:1", "마태복음 11", "마태복음 11:28"].map((query) => [query, benchmark(query)])),
}, null, 2));
