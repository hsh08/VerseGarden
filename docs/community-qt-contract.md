# Community Daily QT Contract

This document defines the Part 10-7 Community Daily QT content boundary. It does not grant access to user QT responses or implement iOS Community lookup.

## Firestore Path

`communities/{communityId}/dailyQuietTimes/{dateKey}`

- `dateKey` is the document ID and follows the existing `YYYY-MM-DD` convention.
- `dateKey` is interpreted in the Community document's timezone. The current default is `Asia/Seoul`.
- There is at most one Community QT document per Community and date.
- Global Daily QT remains at `dailyQuietTimes/{dateKey}`.

## Schema

Community QT reuses the Global Daily QT content contract and adds one required field:

| Field | Type | Notes |
| --- | --- | --- |
| `communityId` | String | Must equal the Community ID in the document path. |
| `dateKey` | String | Must equal the document ID. |
| `timezone` | String | Copied from the Community when the content is created. |
| `title` | String | QT title. |
| `verseId` | String | Primary/start verse ID. |
| `startVerseId` | String? | Start of a same-chapter passage. |
| `endVerseId` | String? | End of a same-chapter passage. |
| `reference` | String | Human-readable passage reference. |
| `translation` | String | Current value: `KRV`. |
| `devotionalText` | String | Main devotional content. |
| `reflectionPrompt` | String | Reflection prompt. |
| `applicationPrompt` | String | Application prompt. |
| `prayerPrompt` | String | Prayer prompt. |
| `questions` | List | Retained for Global QT schema compatibility. |
| `status` | String | `draft`, `published`, or `archived`. |
| `version` | Int | Starts at 1. |
| `createdBy` | String | Authenticated creator UID; immutable. |
| `updatedBy` | String | Authenticated last editor UID. |
| `createdAt` | Timestamp | Immutable creation timestamp. |
| `updatedAt` | Timestamp | Last update timestamp. |
| `publishedAt` | Timestamp? | Set when published. |
| `archivedAt` | Timestamp? | Set when archived. |

Bible text is not duplicated in Firestore. Admin Web and future iOS clients resolve it from the bundled KRV dataset using the verse IDs.

## Status and Version

- `draft`: visible to authorized CMS operators only.
- `published`: direct-readable by active members of the active Community.
- `archived`: retained for CMS history and excluded from the future active-content lookup.
- Content changes increment `version` by exactly one.
- Status-only and timestamp/actor-only changes preserve `version`.
- Version rollback and skipped versions are denied by Firestore Rules.
- Hard delete is denied.

Content fields that affect the version are title, verse IDs/reference, devotional text, prompts, and questions.

## Authorization

| Role | Get/List | Create/Edit/Publish/Archive |
| --- | --- | --- |
| Platform Admin | Any Community QT | Any active Community QT |
| Active Community Admin | Own Community | Own active Community |
| Active Leader | Own Community | Own active Community |
| Active Member | Direct GET of own published QT only | Never |
| Removed/Banned/Left member | Never | Never |
| Signed out / non-member | Never | Never |

Members do not receive collection list permission. Future iOS reads use a direct document GET for today's `dateKey`.

## Community Lifecycle

- `active`: authorized content operators can create, edit, publish, and archive.
- `inactive`: read-only CMS history; member content GET is denied.
- `archived`: read-only CMS history; member content GET is denied.
- Platform Admin can inspect inactive/archived history but cannot mutate it through the Community QT Rules.

## Privacy Boundary

Community QT is shared authored content. It is separate from personal devotional records in:

- `users/{uid}/qtRecords`
- `users/{uid}/prayers`
- `users/{uid}/writingRecords`
- `users/{uid}/verseLists`

Community roles receive no access to those user-owned collections.

## Community QT Submission Projection

Part 10-9.1 adds a trusted-backend submission projection at:

`communities/{communityId}/qtSubmissions/{submissionId}`

The private `users/{uid}/qtRecords/{recordId}` document remains the user's devotional source of truth. A submission is an explicit, limited Community projection containing only:

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | String | Derived from callable authentication. Clients cannot supply it. |
| `displayName` | String | Derived from active membership metadata, with a short UID fallback. |
| `communityId` | String | Must identify the active Community. |
| `dateKey` | String | Submitted Community QT date. |
| `contentId` | String | Must match the Community QT identity for the date. |
| `contentVersion` | Int | Positive version no newer than the currently published content. |
| `contentSource` | String | Always `community`. |
| `reflectionAnswer` | String | Explicitly shared reflection answer. |
| `applicationText` | String | Explicitly shared application text. |
| `completedAt` | Timestamp | Server-authored submission time. |
| `schemaVersion` | Int | Current value: `1`. |

`prayerText`, email, private profile fields, and the complete private QT record are never copied into this projection.

Submission IDs are deterministic SHA-256 hashes of `communityId`, `dateKey`, and authenticated UID. `submitCommunityQT` creates the document in a transaction and treats a retry as already submitted without overwriting the original answer, version, or completion timestamp. Direct Firestore create, update, and delete are denied for every client role.

Only active Community `leader` and `admin` memberships can read or list the projection for their own Community. Normal members, Platform Admin claim alone, inactive memberships, cross-Community users, and signed-out clients cannot read it.

The flat subcollection shape supports future single-field `dateKey` filters and ordering without adding a composite index in Part 10-9.1.

## Admin Participation View

Part 10-9.3 derives Community participation in Admin Web without aggregate documents. The page is available only to authenticated active `leader` and `admin` memberships for their own Community. Platform Admin claim alone is intentionally rejected before any submission read is attempted.

For a selected published Community QT date, the client performs one active-membership list read and one `qtSubmissions` query filtered only by `dateKey`. Completion, incompletion, and participation rate are derived in memory. The denominator is the current set of active `member`, `leader`, and `admin` memberships, so historical percentages may change as membership changes.

Submission detail displays only `reflectionAnswer` and `applicationText` plus non-private submission metadata. It never reads `users/{uid}`, private QT records, prayer records, email, or unrelated activity. `prayerText` is not present in the projection. Malformed or unsupported future schema documents are skipped, and duplicate records for one UID are counted once using the earliest valid immutable submission.

Recent history is sourced from published Community Daily QT documents. A date without published Community QT is shown as no content rather than 0% participation. Dates completed before the submission projection was introduced may undercount and are not migrated.

## Duplicate Protection

The Admin Web checks whether `communities/{communityId}/dailyQuietTimes/{dateKey}` already exists before creating it. The fixed document ID prevents a second record for the same date, and existing content is never silently overwritten by the create flow.

## Future iOS Resolution

Part 10-7 does not modify iOS. The intended future resolution order is:

1. Direct GET `communities/{communityId}/dailyQuietTimes/{dateKey}` and use it only when published.
2. Direct GET `dailyQuietTimes/{dateKey}` and use it only when published.
3. Use the existing bundled local fallback.

Future QT records can identify the selected source with `communityId`, `contentSource` (`community`, `global`, or `local`), `contentId`, `contentDateKey`, and `contentVersion` without changing this content schema.

## Read/Write Cost

- CMS list: one scoped subcollection query, limited by the Admin Web to recent content.
- CMS detail: one Community document read and one QT document read.
- CMS mutation: one duplicate-check read for create, followed by one write; edit/status changes use one write.
- Future iOS: one Community direct GET, then at most one Global direct GET on fallback.
- No N+1 member reads, Cloud Functions, or new composite indexes are required.
