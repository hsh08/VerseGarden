# Community Admin Authorization Contract

This document defines the Part 10-5 administrative authorization boundary for VerseGarden.

## Administrative Authorities

### Platform Admin

Platform Admin is the Firebase Auth custom claim `{ admin: true }`. It is the only authority that can:

- list and manage all Communities;
- create Communities and change lifecycle status;
- manage global `dailyQuietTimes` content;
- assign `member`, `leader`, or `admin` Community roles through the trusted callable;
- inspect operational Community and membership metadata.

### Community Admin / Leader

Community authority is data-driven and comes only from:

`communities/{communityId}/members/{uid}`

The membership must have `status == active` and `role in [leader, admin]`. Community roles are not copied into Firebase Custom Claims and are not read from `users/{uid}` or browser storage.

Both roles are scoped to their own active Community, but they do not have the same authority:

- `admin` is a Community Admin. It can manage invite lifecycle operations and change active `member`/`leader` roles within its own Community.
- `leader` is a read and day-to-day ministry role. It can view Community overview and membership metadata, but cannot manage roles or invite lifecycle operations.

The membership enum value `admin` is distinct from the Platform Admin custom claim `{ admin: true }`.

## Community Admin Discovery

The Admin Web calls `getMyAdminCommunities` after Firebase Auth has confirmed that the user does not have the Platform Admin claim. The callable:

1. uses the authenticated caller UID;
2. performs a server-side `collectionGroup("members")` lookup by the membership `uid` field;
3. filters to active `leader`/`admin` memberships;
4. returns only Community ID, name, role, and Community status.

This lookup requires a collection-group single-field index for `members.uid`, defined in `firestore.indexes.json`. No client collection-group access is granted.

## Auth State Model

Admin Web states are:

- `loading`
- `signedOut`
- `denied`
- `platformAdmin`
- `communityAdmin`

ID token claims are refreshed on auth state resolution, not on every render. Community scopes are cached in the auth provider for the session. A selected Community ID is UX state only and never an authorization source.

## Route Access

Platform Admin retains:

- `/admin`
- `/admin/qt/**`
- `/admin/communities/**`

Community Admin and Leader receive:

- `/admin`
- `/admin/community/{authorizedCommunityId}`

Direct access to global QT, the platform Community list, or another Community ID is blocked by the Admin Web route guard. The route guard is UX only; Firestore Rules and callable authorization remain the security boundary.

## Role Assignment

`setCommunityMemberRole` is a narrow trusted callable. It validates the Community, caller membership, target membership, role enum, membership UID consistency, and active status. It updates only `role` and `updatedAt`.

- Platform Admin may assign `member`, `leader`, or `admin`, subject to primary-leader safety.
- Community Admin may change active `member` and `leader` memberships only within its own active Community.
- Community Admin cannot assign `admin`, modify an existing Community Admin, change its own role, or target another Community.
- Leader and Member cannot change roles.

All client Firestore membership writes remain denied; role changes always pass through the trusted callable.

## Primary Leader

`primaryLeaderUid` remains read-only in Part 10-5. A separate primary-leader assignment operation is deferred. To prevent inconsistent state, `setCommunityMemberRole` rejects changing the current primary leader to `member`. Changing that membership between `admin` and `leader` remains valid.

## Community Lifecycle

- `active`: scoped read access and invite create/regenerate/revoke are available when `inviteEnabled` is true.
- `inactive`: scoped historical reads remain; invite create/regenerate are disabled; existing invites may be revoked.
- `archived`: scoped historical reads remain; invite create/regenerate are disabled; existing invites may be revoked.

Archive, restore, activate, and deactivate remain Platform Admin operations.

## Invitation Access

Platform Admin and Community Admin can create, regenerate, revoke, and list safe invite metadata through trusted Functions. Community Admin is limited to its own active Community. Leader and Member cannot manage invite lifecycle operations. `listManagedCommunityInvites` excludes `codeHash` and plaintext codes. Plaintext generated codes remain transient React state only.

## Member Identity

The product identity source remains `users/{uid}`. A trusted invite redemption reads `nickname` first, then `displayName`, and finally the Firebase Auth token name. A normalized safe display name may be copied to `communities/{communityId}/members/{uid}.displayName` as an operational snapshot.

Clients cannot submit a trusted display name during invite redemption, and Community management does not receive broad read access to `users/{uid}`. Email and private devotional records are not copied to memberships. Existing memberships without a snapshot render as `사용자` with a shortened UID as secondary metadata; no destructive backfill is required.

## Global QT And Private Data

Global `dailyQuietTimes` remains Platform Admin-managed. Community Admin can read a published document only as an ordinary signed-in user and cannot list, create, update, publish, archive, or delete global QT content.

Neither Platform Admin nor Community Admin receives access to private user devotional subcollections such as prayers, QT answers, writing records, VerseLists, or liked verses. Existing owner-only Rules remain unchanged.

## Deferred

- Community metadata editing by Community Admin;
- member remove/ban operations;
- primary leader assignment UI/callable;
- Community Daily QT;
- participation analytics;
- platform user directory;
- organization hierarchy.
