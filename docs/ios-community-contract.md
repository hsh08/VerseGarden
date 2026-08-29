# VerseGarden iOS Community Contract

## Scope

Part 10-8 adds the member-facing Community surface to the existing iOS app. Community remains under Profile and does not add a bottom tab. Administrative actions remain in Admin Web.

## Community State

`CommunityStore` is the app-level, main-actor state owner for:

- the authenticated user's active memberships
- the selected operational Community
- loading, empty, and transient error states
- refresh after invite redemption
- clearing state on logout or account change

Membership authorization is never inferred from a local Community ID. The canonical membership is `communities/{communityId}/members/{uid}` and is resolved by the authenticated `getMyCommunities` callable.

The callable returns only the caller's active membership summaries. It does not return other members, invite data, private user data, or private devotional records. Memberships in `removed`, `banned`, or `left` state are excluded. Memberships in inactive or archived Communities are retained only as non-operational summaries and cannot become the selected Community.

## Multiple Communities

The store accepts multiple active memberships. The selected Community ID is a per-user local UX preference. It is validated against the current active membership response on every refresh; an invalid or missing preference falls back deterministically to the first active membership returned by the server.

No multi-Community picker is exposed in Part 10-8.

## Invite Redemption

`CommunityJoinView` calls `redeemCommunityInvite` in `us-central1` through `CommunityCallableService`.

- input is trimmed and normalized to uppercase
- the submit action is disabled during the request
- membership creation remains a trusted backend transaction
- successful redemption refreshes `CommunityStore` before the join screen is dismissed
- Firebase implementation details and raw errors are not exposed to users

The client never writes a membership document directly.

## Profile UI States

The `나의 공동체` section has four explicit states:

1. loading: membership discovery is still running
2. no Community: invite-code entry is offered
3. joined: Community name and translated role link to Community detail
4. error: the last known state is retained when possible and a retry action is available

`CommunityDetailView` exposes only Community identity, today's QT, the current user's role and join date, and an optional aggregate member count. It does not fetch or display a member directory or other users' private data.

## Daily QT Resolution

For an active selected Community, today's content is resolved in this order:

1. direct GET `communities/{communityId}/dailyQuietTimes/{communityDateKey}`
2. direct GET `dailyQuietTimes/{globalDateKey}`
3. the existing bundled local fallback

Community date keys use the Community's IANA timezone. Global date keys retain the existing `Asia/Seoul` behavior. No Community QT list query is used.

A Community document is accepted only when:

- it exists
- `status == published`
- its `dateKey` matches the requested date key
- its `communityId` matches the selected Community

Invalid, missing, inaccessible, inactive, or archived Community content falls back safely. Scripture text and multi-verse ranges are resolved from the bundled Bible dataset; Firestore `verseText` is not used.

## QT Record Metadata

Private QT records remain at `users/{uid}/qtRecords/{recordId}`. `QTRecord` adds backward-compatible optional metadata:

- `contentSource`: `community`, `global`, or `local`
- `communityId`: populated only for Community content

Existing records without these fields continue to decode. `contentId`, `contentDateKey`, and `contentVersion` continue to identify the exact content version consumed by the user. Reflection, application, and prayer answers are never written under a Community document.

## Community Submission

Part 10-9.2 connects completed Community QT records to the trusted `submitCommunityQT` callable described in `community-qt-contract.md`. Private completion remains local-first: iOS saves the complete private `QTRecord` and adds the existing Garden activity before attempting the Community projection. A network failure cannot roll back or block either private operation.

Before the answer fields, Community QT shows a sharing disclosure. Reflection and application are labeled as shared with the Community; prayer is labeled as private. Global and bundled-local QT do not show this disclosure and are never submitted to a Community.

The callable payload contains only `communityId`, `dateKey`, `contentId`, `contentVersion`, `reflectionAnswer`, and `applicationText`. `prayerText` is never sent to the callable or persisted in the retry queue.

The local retry queue is scoped by Firebase Auth UID and stores identifiers only: private record ID, `communityId`, `contentId`, `dateKey`, and `contentVersion`. Before each attempt, iOS reconstructs the allowed answer payload from the corresponding private `QTStore` record and validates that its immutable content identity still matches the queue item.

Retries run immediately after Community QT completion, when the app returns to the foreground, and after the authenticated user's private QT records have been restored during session synchronization. Retryable network/service failures retain the queue item. Authentication failures retain it until the matching user session is restored. Invalid or permanently rejected items are removed. A successful or `alreadySubmitted` callable response removes the item without creating another Garden activity.

If the private record cannot be restored or no longer matches the queued content identity, the stale item is removed rather than fabricating empty answers. Queue keys and in-memory state are isolated by UID and cleared from the active session on logout; another account cannot submit the previous user's pending answers.

## Garden

The existing `QTRecord -> GardenActivity.qtCompleted` derivation is unchanged. Community QT completion counts as the same private spiritual activity and does not introduce a Community-specific Garden activity type.

## Logout And Account Switching

An authentication UID change immediately clears `CommunityStore` and the resolved QT cache. Logout also clears both stores before another user can load. Per-user selected Community keys remain isolated by UID and are only UX preferences, never authorization data.

## Leave Policy

Part 10-8 does not expose a leave action. There is no safe user-facing leave callable in the current backend, and the iOS client must not mutate membership status directly. A trusted transactional leave policy, including leader/admin safeguards and member-count handling, is deferred to Part 10-8.1.

## Required Functions

- existing deployed `redeemCommunityInvite`
- new `getMyCommunities` callable in `us-central1`

`getMyCommunities` must be deployed before production iOS QA. Firestore Rules, indexes, Hosting, and unrelated Functions do not require deployment for this implementation.
