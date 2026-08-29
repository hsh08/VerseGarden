# VerseGarden Community Invite Contract

Part 10-3 introduces trusted invite creation and redemption for communities. The iOS app and Admin Web must not create or redeem invite documents directly. All mutations go through Firebase Cloud Functions using the Admin SDK.

## Firestore Collections

### `communityInvites/{inviteHash}`

The document ID is `sha256(normalizedInviteCode)`. The plaintext invite code is returned once by the create/regenerate function and is never stored in Firestore.

Required fields:

- `communityId: string`
- `codeHash: string`
- `status: "active" | "revoked" | "expired"`
- `createdBy: string`
- `createdAt: Timestamp`
- `updatedAt: Timestamp`
- `useCount: number`

Optional fields:

- `expiresAt: Timestamp`
- `maxUses: number`
- `lastUsedAt: Timestamp`
- `label: string`

## Invite Code Format

Plaintext codes use:

```text
VG-XXXXXXXX-XXXXXXXX
```

Codes are normalized by uppercasing and removing separators before hashing. The normalized form is `VG` plus 16 non-ambiguous alphanumeric characters.

## Authorization

Invite creation:

- Platform admin can create invites for any active community.
- Community `admin` or `leader` can create invites only for their own active community.
- Community `member`, non-member, and signed-out users are denied.

Invite revocation/regeneration:

- Platform admin can revoke/regenerate any invite.
- Community `admin` or `leader` can revoke/regenerate invites only for their own community.
- Members and non-members are denied.

Invite redemption:

- Signed-in user required.
- Invite must exist, be active, not expired, and not exceed `maxUses`.
- Community must exist and have `status == "active"`.
- Community must not have `inviteEnabled == false`.
- Existing active membership returns success without incrementing `useCount` or `memberCount`.
- Existing `left` membership may rejoin and increments `useCount` and `memberCount`.
- Existing `removed` or `banned` membership is denied.
- New membership is created as `role == "member"` and `status == "active"`.

## Firestore Rules Boundary

Client SDK access to `communityInvites` is read-only for platform admins and write-denied for everyone. Trusted Cloud Functions use the Admin SDK and bypass Firestore Rules for invite mutation.

Invite creation and regeneration require an active Community with invites enabled. Revocation remains available to authorized managers after a Community becomes inactive or archived so stale codes can be retired safely.

## Member Count Policy

`communities/{communityId}.memberCount` is updated by the redeem transaction for new joins and left-member rejoins. Duplicate redemption by an already active member is idempotent and does not increment counts.

## Out of Scope

- Invite UI
- Invite analytics
- Rate limiting
- Email delivery
- Community creation UI
- Production deployment
