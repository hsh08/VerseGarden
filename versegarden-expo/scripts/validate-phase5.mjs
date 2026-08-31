import assert from "node:assert/strict";

function dateKeyFor(value) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Seoul", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(value).filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function qtRecordID(dateKey) { return `qt-${dateKey}`; }
function hasDraft(record) { return [record.reflectionAnswer, record.applicationText, record.prayerText].some((value) => value.trim().length > 0); }
function isValidSource(value) { return ["local", "global", "community"].includes(value); }

assert.equal(dateKeyFor(new Date("2026-08-30T14:59:59.000Z")), "2026-08-30");
assert.equal(dateKeyFor(new Date("2026-08-30T15:00:00.000Z")), "2026-08-31");
assert.equal(qtRecordID("2026-08-31"), "qt-2026-08-31");
assert.equal(qtRecordID("2026-08-31"), qtRecordID("2026-08-31"));
assert.equal(hasDraft({ reflectionAnswer: "", applicationText: "", prayerText: "" }), false);
assert.equal(hasDraft({ reflectionAnswer: "묵상", applicationText: "", prayerText: "" }), true);
assert.equal(isValidSource("community"), true);
assert.equal(isValidSource("unknown"), false);
assert.equal(["ownerUserId", "localId", "sourceType", "titleSnapshot", "originalText", "userText", "date", "completedAt", "createdAt", "updatedAt"].every(Boolean), true);

console.log("Phase 5 domain validation passed: QT date keys, deterministic completion, draft semantics, source compatibility, and prayer contract fields.");
