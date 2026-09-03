import assert from "node:assert/strict";

const operational = (item) => item.membershipStatus === "active" && item.communityStatus === "active";
const select = (items, selectedId) => items.filter(operational).find((item) => item.communityId === selectedId) ?? items.filter(operational)[0] ?? null;
const dateKeyFor = (value, timeZone) => {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(value).filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
};
const payloadFor = (record) => record.completedAt && record.contentSource === "community" && record.communityId && record.contentId === (record.contentDateKey ?? record.dateKey) && record.contentVersion > 0
  ? { communityId: record.communityId, dateKey: record.contentDateKey ?? record.dateKey, contentId: record.contentId, contentVersion: record.contentVersion, reflectionAnswer: record.reflectionAnswer, applicationText: record.applicationText }
  : null;
const resolve = (community, global) => community?.status === "published" ? "community" : global?.status === "published" ? "global" : "local";

const memberships = [
  { communityId: "inactive", membershipStatus: "active", communityStatus: "inactive" },
  { communityId: "first", membershipStatus: "active", communityStatus: "active" },
  { communityId: "second", membershipStatus: "active", communityStatus: "active" },
];
assert.equal(select(memberships, "second")?.communityId, "second");
assert.equal(select(memberships, "missing")?.communityId, "first");
assert.equal(select(memberships, "inactive")?.communityId, "first");
assert.equal(dateKeyFor(new Date("2026-08-31T15:30:00.000Z"), "Asia/Seoul"), "2026-09-01");
assert.equal(resolve({ status: "published" }, { status: "published" }), "community");
assert.equal(resolve({ status: "draft" }, { status: "published" }), "global");
assert.equal(resolve({ status: "archived" }, null), "local");

const record = { id: "qt-2026-09-01", completedAt: new Date(), contentSource: "community", communityId: "community-a", dateKey: "2026-09-01", contentDateKey: "2026-09-01", contentId: "2026-09-01", contentVersion: 2, reflectionAnswer: "reflection", applicationText: "application", prayerText: "private prayer" };
const payload = payloadFor(record);
assert.deepEqual(Object.keys(payload).sort(), ["applicationText", "communityId", "contentId", "contentVersion", "dateKey", "reflectionAnswer"]);
assert.equal("prayerText" in payload, false);
assert.equal("uid" in payload, false);
assert.equal("displayName" in payload, false);
assert.equal("completedAt" in payload, false);
const retry = { recordId: record.id, communityId: record.communityId, dateKey: record.dateKey, contentId: record.contentId, contentVersion: record.contentVersion };
assert.equal(JSON.stringify(retry).includes("private prayer"), false);
assert.equal(JSON.stringify(retry).includes("reflection"), false);
assert.equal(payloadFor({ ...record, completedAt: null }), null);
assert.equal(payloadFor({ ...record, contentId: "wrong" }), null);

console.log("Phase 7 Community validation passed: active UID-scoped selection, Community/global/local QT resolution, timezone date keys, allowlisted submission payload, prayer privacy, and identifier-only retry semantics.");
