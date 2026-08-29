# Community Data Contract

This document defines the VerseGarden Community Firestore contract introduced in Part 10-2.

Part 10-2 establishes the security foundation only. It does not implement Community UI, invite redemption, Community QT, participation analytics, Organizations, or migrations.

## Authorization Source Of Truth

Community authorization is always derived from:

`communities/{communityId}/members/{uid}`

Do not use `users/{uid}.communityIds`, `users/{uid}.primaryCommunityId`, or any other denormalized user field as an authorization source. Future user-level Community fields may be added for iOS UX/cache convenience only.

## Platform Admin

Platform Admin remains the existing Firebase Auth custom claim:

```json
{ "admin": true }
```

This is the root VerseGarden platform privilege. Community leaders and Community admins must not receive this claim.

## Community Collection

Path:

`communities/{communityId}`

### Required Fields

| Field | Type | Notes |
| --- | --- | --- |
| `name` | String | Non-empty display name. |
| `status` | String | `active`, `inactive`, or `archived`. |
| `timezone` | String | MVP default should usually be `Asia/Seoul`. |
| `createdBy` | String | Creator UID. |
| `updatedBy` | String | Last updater UID. |
| `createdAt` | Timestamp | Firestore timestamp. Immutable after create. |
| `updatedAt` | Timestamp | Firestore timestamp. |

### Optional Fields

| Field | Type | Notes |
| --- | --- | --- |
| `description` | String | Short community description. |
| `primaryLeaderUid` | String | UX pointer only; membership role remains source of truth. |
| `inviteEnabled` | Bool | Whether future invites may be accepted. |
| `memberCount` | Int | Optional denormalized count. Should be maintained by trusted backend if used. |

### Status Values

- `active`: normal operation.
- `inactive`: joining should be disabled; historical access may remain.
- `archived`: invite disabled, new Community QT should eventually be disabled, history preserved.

Client hard delete is prohibited by Firestore Rules. Historical references should remain valid.

## Membership Subcollection

Path:

`communities/{communityId}/members/{uid}`

### Required Fields

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | String | Must equal document ID. |
| `role` | String | `member`, `leader`, or `admin`. |
| `status` | String | `active`, `removed`, `banned`, or `left`. |
| `joinedAt` | Timestamp | Firestore timestamp. Immutable after create. |
| `updatedAt` | Timestamp | Firestore timestamp. |

### Optional Fields

| Field | Type | Notes |
| --- | --- | --- |
| `displayName` | String | Denormalized member display name for admin/member lists. |
| `invitedBy` | String | UID of inviter or trusted backend actor. |

### Roles

- `member`: normal Community participant.
- `leader`: scoped Community manager. Currently treated like `admin` for rule helper purposes.
- `admin`: scoped Community manager.

`leader` and `admin` are separate values to preserve room for future permission differences.

### Membership Status Values

- `active`: counts as active membership.
- `removed`: removed by an admin/trusted operation.
- `banned`: explicitly blocked from active membership.
- `left`: user left the Community.

Only `active` membership grants Community member/admin helper permissions.

## Firestore Rules Behavior In Part 10-2

### Platform Admin

Can:

- list/read all Community documents.
- create valid Community documents.
- update valid Community documents while preserving `createdBy` and `createdAt`.
- list/read membership documents.
- create/update valid membership documents while preserving `uid` and `joinedAt`.

Cannot:

- hard delete Community documents from client Rules.
- hard delete membership documents from client Rules.
- bypass Community or membership shape validation when writing through the client SDK.

Firebase Admin SDK writes bypass Firestore Rules. Trusted server code must enforce equivalent validation when using Admin SDK.

### Community Admin / Leader

Source:

`communities/{communityId}/members/{uid}` with `status == "active"` and `role in ["leader", "admin"]`.

Can:

- read its own Community document.
- read/list membership metadata in its own Community.

Cannot in Part 10-2:

- create arbitrary Communities.
- create membership documents.
- update roles or statuses.
- access another Community.
- edit global Daily QT.
- read private user subcollections.

### Member

Source:

`communities/{communityId}/members/{uid}` with `status == "active"`.

Can:

- read its own Community document.
- read its own membership document.

Cannot:

- create membership for itself or another user.
- promote itself.
- change its own status.
- list all members.
- access another Community.
- read private user subcollections.

### Non-member / Signed-out User

Cannot access Community-private data.

## Private User Data Boundary

The following paths remain owner-only and are not readable by Platform Admin or Community Admin through Firestore Rules:

- `users/{uid}`
- `users/{uid}/writingRecords`
- `users/{uid}/verseLists`
- `users/{uid}/verseLists/{listId}/items`
- `users/{uid}/likedVerses`
- `users/{uid}/qtRecords`
- `users/{uid}/prayers`
- `users/{uid}/prayerWritingRecords`
- `users/{uid}/writingPlans`
- `users/{uid}/writingPlans/{planId}/days`

Do not weaken these owner-only rules for participation features. A trusted backend may create a separate, explicitly disclosed Community projection containing only the approved shared reflection and application fields. It must never expose prayer text, email, private profile fields, devotional journal data, or the complete private QT record.

## Global Daily QT Compatibility

The global Daily QT path remains:

`dailyQuietTimes/{dateKey}`

Existing behavior remains:

- Platform Admin can list/read/create/update according to the existing Daily QT contract.
- Signed-in users can directly get published Daily QT documents.
- Signed-in users cannot get draft or archived Daily QT documents.
- Community Admin without `{ admin: true }` cannot edit global Daily QT.

## Future Invite Architecture

Part 10-2 does not implement invite codes or redemption.

Future Part 10-3 should implement trusted invite redemption through Firebase Admin SDK or another trusted server surface. It must:

- generate non-predictable invite codes.
- avoid storing plaintext invite codes when feasible.
- validate invite status, Community status, expiry, and use limits.
- create membership documents server-side.
- prevent users from forging membership by direct client writes.
- maintain `memberCount` if that optional field is used.

Do not implement invite redemption by allowing:

```text
allow create: if request.auth.uid == uid
```

on membership documents.

## Future Community QT Path

Potential path:

`communities/{communityId}/dailyQuietTimes/{dateKey}`

Community QT should reuse the existing global Daily QT schema where practical. It is intentionally not implemented in Part 10-2.

Recommended future iOS resolution:

1. Community published QT for user's active/primary Community.
2. Global published QT.
3. Existing local fallback.

## Community QT Submission Projection

Part 10-9.1 introduces the trusted-backend path:

`communities/{communityId}/qtSubmissions/{submissionId}`

The callable copies only explicitly shared `reflectionAnswer` and `applicationText` plus server-derived identity/content metadata. `prayerText` and the complete private QT record remain owner-only. Active Community leaders and admins can read their own Community's projection; normal members and Platform Admin claim alone cannot. Direct client writes are denied.

Aggregate participation and analytics documents remain deferred. They should be derived from trusted submission metadata rather than weakening access to private user records.

## Future Organization Expansion

Organizations are not implemented in Part 10-2.

The current schema can later support:

`organizations/{organizationId}`

and:

`communities/{communityId}.organizationId`

as an optional field after Firestore Rules and contracts are updated. Existing Community document IDs do not need to change.

## Intentionally Not Implemented In Part 10-2

- Community creation UI.
- Community list/detail UI.
- iOS Community screen.
- invite generation.
- invite redemption.
- Community join/leave flow.
- Community Admin dashboard.
- Community switcher.
- Community Daily QT.
- participation tracking or analytics.
- Platform user directory UI.
- Organization/Church hierarchy.
- chat/feed/comments.
- payments.
- push notifications.
- hard delete.
- existing user migration.
