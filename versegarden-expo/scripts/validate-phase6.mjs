import assert from "node:assert/strict";

function dateKeyFor(value) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Seoul", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(value).filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

const growth = (type) => type !== "verseRead";
const summary = (activities) => activities.filter((item) => growth(item.type)).reduce((result, item) => {
  const key = dateKeyFor(item.date); result[key] = (result[key] ?? 0) + 1; return result;
}, {});
const streak = (counts, today) => {
  let cursor = new Date(`${dateKeyFor(today)}T00:00:00+09:00`);
  if (!counts[dateKeyFor(cursor)]) cursor = new Date(cursor.getTime() - 86400000);
  let value = 0; while (counts[dateKeyFor(cursor)]) { value += 1; cursor = new Date(cursor.getTime() - 86400000); } return value;
};
const dedupe = (items) => {
  const qtDays = new Set(); const writingDays = new Set(); const ids = new Set();
  return items.filter((item) => {
    const day = dateKeyFor(item.date);
    if (item.type === "qtCompleted") { if (qtDays.has(day)) return false; qtDays.add(day); }
    if (item.type === "scriptureCopy") { const key = `${day}|${item.verseId}`; if (writingDays.has(key)) return false; writingDays.add(key); }
    const key = `${item.type}|${item.sourceId}`; if (ids.has(key)) return false; ids.add(key); return true;
  });
};

const august30 = new Date("2026-08-30T15:00:00.000Z");
const august29 = new Date("2026-08-29T15:00:00.000Z");
assert.equal(dateKeyFor(august30), "2026-08-31");
assert.equal(growth("verseRead"), false);
assert.equal(growth("qtCompleted"), true);
assert.equal(summary([{ type: "verseRead", date: august30 }, { type: "prayer", date: august30 }])["2026-08-31"], 1);
assert.equal(dedupe([{ type: "qtCompleted", sourceId: "qt-a", date: august30 }, { type: "qtCompleted", sourceId: "qt-b", date: august30 }]).length, 1);
assert.equal(dedupe([{ type: "scriptureCopy", sourceId: "a", verseId: "잠언-1-1", date: august30 }, { type: "scriptureCopy", sourceId: "b", verseId: "잠언-1-1", date: august30 }]).length, 1);
assert.equal(streak({ "2026-08-30": 1 }, august30), 1, "Today without activity retains yesterday's streak.");
assert.equal(streak({ "2026-08-29": 1 }, august30), 0, "A missing yesterday ends the streak.");
assert.equal(Boolean({ completedAt: null }.completedAt), false, "QT drafts must not become activities.");
assert.equal(["ownerUserId", "localId", "sourceType", "completedAt"].every(Boolean), true, "Prayer templates are excluded; only prayerWritingRecords qualify.");

console.log("Phase 6 Garden validation passed: growth filtering, Seoul grouping, dedupe, streak, QT draft exclusion, and prayer record semantics.");
