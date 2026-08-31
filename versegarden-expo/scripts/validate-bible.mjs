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

const indexStartedAt = performance.now();
const versesWithID = verses.map((verse) => ({ ...verse, id: createVerseId(verse.book, verse.chapter, verse.verse) }));
const entries = versesWithID.map((verse) => ({ verse, normalizedText: normalize(verse.text), normalizedReference: compactReference(`${verse.book}${verse.chapter}:${verse.verse}`), normalizedShortReference: compactReference(`${verse.book.slice(0, 1)}${verse.chapter}:${verse.verse}`) }));
const entriesByBook = new Map();
for (const entry of entries) {
  const key = normalize(entry.verse.book);
  entriesByBook.set(key, [...(entriesByBook.get(key) ?? []), entry]);
}
const aliases = new Map();
for (const book of entriesByBook.keys()) {
  for (const alias of [book, book.slice(0, 1)]) aliases.set(alias, new Set([...(aliases.get(alias) ?? []), book]));
}
const bookAliases = new Map([...aliases.entries()].map(([alias, values]) => [alias, [...values].sort((left, right) => right.length - left.length)]));
const indexBuildMilliseconds = performance.now() - indexStartedAt;

function limitResults(matches, limit) {
  return { verses: matches.slice(0, limit).map((entry) => entry.verse), hasMoreResults: matches.length > limit };
}

function search(query, limit = 12) {
  const normalizedQuery = normalize(query);
  const compactQuery = compactReference(query);
  if (!normalizedQuery || limit < 1) return { verses: [], hasMoreResults: false };

  const alias = [...bookAliases.keys()].sort((left, right) => right.length - left.length).find((value) => compactQuery.startsWith(value));
  if (alias) {
    const suffix = compactQuery.slice(alias.length);
    if (!suffix || /^\d/.test(suffix)) {
      const candidates = bookAliases.get(alias).flatMap((book) => entriesByBook.get(book) ?? []);
      if (!suffix) return limitResults(candidates, limit);
      const [chapterValue, verseValue] = suffix.split(":", 2);
      const chapter = Number(chapterValue);
      const verse = verseValue === undefined ? null : Number(verseValue);
      if (Number.isInteger(chapter) && (verse === null || Number.isInteger(verse))) return limitResults(candidates.filter((entry) => entry.verse.chapter === chapter && (verse === null || entry.verse.verse === verse)), limit);
    }
  }

  return limitResults(entries.filter((entry) => entry.normalizedText.includes(normalizedQuery) || entry.normalizedReference.includes(compactQuery) || entry.normalizedShortReference.includes(compactQuery)), limit);
}

assert.equal(verses.length, 31089, "The bundled dataset verse count changed unexpectedly.");
assert.equal(createVerseId("창세기", 1, 1), "창세기-1-1");
assert.deepEqual(parseVerseId("마태복음-11-28"), { book: "마태복음", chapter: 11, verse: 28 });
assert.equal(parseVerseId("malformed"), null);
assert.equal(new Set(versesWithID.map((verse) => verse.id)).size, versesWithID.length, "Verse IDs must be unique.");
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
  indexBuildMilliseconds: Number(indexBuildMilliseconds.toFixed(3)),
  benchmarks: Object.fromEntries(["사랑", "예수", "요한", "창세기", "창세기 1:1", "마태복음 11", "마태복음 11:28"].map((query) => [query, benchmark(query)])),
}, null, 2));
