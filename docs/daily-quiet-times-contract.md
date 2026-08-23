# Daily Quiet Times Data Contract

This document defines the Firestore contract for the VerseGarden Admin Web / QT CMS foundation.

## Collection

`dailyQuietTimes/{dateKey}`

- `dateKey` is the document ID.
- Format: `YYYY-MM-DD`
- Initial content timezone: `Asia/Seoul`
- This collection stores admin-authored QT content only.
- User QT completion records remain in `users/{uid}/qtRecords/{recordId}`.

## Required Fields

| Field | Type | Notes |
| --- | --- | --- |
| `dateKey` | String | Must equal the document ID. |
| `timezone` | String | MVP value: `Asia/Seoul`. |
| `title` | String | QT title shown to users. |
| `verseId` | String | Legacy-compatible primary verse ID. For range content, use the start verse ID. |
| `reference` | String | Human-readable verse or verse range reference. |
| `translation` | String | MVP value: `KRV`. |
| `devotionalText` | String | Main QT devotional body. |
| `reflectionPrompt` | String | Reflection prompt. |
| `applicationPrompt` | String | Application prompt. |
| `prayerPrompt` | String | Prayer prompt. |
| `questions` | List | Deprecated UI field. Keep `[]` for schema compatibility. |
| `status` | String | `draft`, `published`, or `archived`. |
| `version` | Int | Starts at `1`; increment when content fields change. Status-only changes do not increment it. |
| `createdBy` | String | Admin UID. |
| `updatedBy` | String | Admin UID. |
| `createdAt` | Timestamp | Firestore timestamp. |
| `updatedAt` | Timestamp | Firestore timestamp. |

## Optional Fields

| Field | Type | Notes |
| --- | --- | --- |
| `publishedAt` | Timestamp | Set when content is published. |
| `archivedAt` | Timestamp | Set when content is archived. |
| `startVerseId` | String | Start verse ID for multi-verse content. |
| `endVerseId` | String | End verse ID for multi-verse content. Same as `startVerseId` for single verse content. |

## Bible Range

Verse IDs must use the same rule as the bundled iOS/Admin Bible dataset:

`{book}-{chapter}-{verse}`

Examples:

- Single verse: `요한복음-1-1`
- Same-chapter range: `이사야-40-27` to `이사야-40-31`

Firestore does not store full Bible text. Clients resolve the full passage from bundled `bible_krv_full.json`.

## Example Document

```json
{
  "dateKey": "2026-08-24",
  "timezone": "Asia/Seoul",
  "title": "말씀 안에서 하루를 시작해요",
  "verseId": "이사야-40-27",
  "startVerseId": "이사야-40-27",
  "endVerseId": "이사야-40-31",
  "reference": "이사야 40:27-31",
  "translation": "KRV",
  "devotionalText": "오늘의 말씀을 천천히 읽고 마음에 남는 부분을 묵상해보세요.",
  "reflectionPrompt": "오늘 말씀에서 가장 마음에 남는 단어는 무엇인가요?",
  "applicationPrompt": "오늘 내가 순종으로 실천할 작은 행동은 무엇인가요?",
  "prayerPrompt": "말씀대로 살아가도록 짧게 기도해보세요.",
  "questions": [],
  "status": "draft",
  "version": 1,
  "createdBy": "ADMIN_UID",
  "updatedBy": "ADMIN_UID",
  "createdAt": "Firestore Timestamp",
  "updatedAt": "Firestore Timestamp"
}
```

## Permission Model

Admin authority uses Firebase Auth Custom Claims:

```json
{
  "admin": true
}
```

Do not use `users/{uid}.role` or `users/{uid}.isAdmin` as the authority source, because user documents are owner-writable.

## Read / Write Policy

| Action | Normal signed-in user | Admin |
| --- | --- | --- |
| Read `published` | Yes | Yes |
| Read `draft` | No | Yes |
| Read `archived` | No | Yes |
| List content | No | Yes |
| Create | No | Yes |
| Update | No | Yes |
| Delete `draft` | No | Yes |
| Delete `published` | No | No |
| Delete `archived` | No | Yes |

## iOS Lookup Policy

Future iOS integration should resolve today's QT with direct document lookup:

`dailyQuietTimes/{dateKey}`

The app should compute `dateKey` using the content timezone, then fetch the document and only use it when `status == "published"`.

If the fetch fails or no published content exists, the app should keep using the existing local QT fallback.
