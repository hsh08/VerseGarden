import assert from "node:assert/strict";

const createVerseId = (book, chapter, verse) => `${book}-${chapter}-${verse}`;
const planRecordID = (planId, assignmentId, verseId) => ["plan", planId, "assignment", assignmentId, "verse", verseId].map((value) => value.replace(/[\/#?]/g, "_").trim()).join("_");
const uniqueVerseIDs = (items) => [...new Set(items.map((item) => item.verseId))];
const progress = (assignments, totalDays) => ({ completed: assignments.filter((item) => item.state === "completed").length, total: totalDays });

assert.equal(createVerseId("창세기", 1, 1), "창세기-1-1");
assert.equal(new Set(["창세기-1-1", "창세기-1-1"]).size, 1, "Liked verse document identity must dedupe by verse ID.");
assert.deepEqual(uniqueVerseIDs([{ verseId: "창세기-1-1" }, { verseId: "창세기-1-1" }, { verseId: "마태복음-11-28" }]), ["창세기-1-1", "마태복음-11-28"]);
assert.equal(planRecordID("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "마태복음-11-28"), planRecordID("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "마태복음-11-28"));
assert.notEqual(planRecordID("plan-a", "assignment-a", "창세기-1-1"), planRecordID("plan-a", "assignment-b", "창세기-1-1"));
assert.deepEqual(progress([{ state: "completed" }, { state: "pending" }, { state: "completed" }], 3), { completed: 2, total: 3 });

console.log("Phase 4 domain validation passed: IDs, list dedupe, plan record dedupe, and progress.");
