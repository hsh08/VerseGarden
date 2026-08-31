# VerseGarden Android Expo

This directory is the Android-first React Native foundation for VerseGarden. The existing SwiftUI iOS app remains the production reference while the Android client is built incrementally with compatible Firebase contracts.

## Current scope

- Expo Router navigation shell: Verse, Prayer, Home, Garden, and Profile
- VerseGarden design tokens and reusable UI primitives
- Firebase JavaScript SDK initialization layer
- React Native Firebase Auth persistence through AsyncStorage
- SQLite schema-version foundation for future local-first records
- Email/password login, signup, password reset, logout, and persistent sessions
- Firestore `users/{uid}` profile loading and the shared onboarding gate

Local Bible reading, browsing, search, verse detail, likes, VerseList, free writing, writing plans, daily QT, and personal prayer records are available. QT uses published global content when it exists and safely falls back to the bundled Bible. Community QT submission, Garden behavior, Community features, notifications, and widgets are not implemented yet.

## Install and run

```bash
npm install
cp .env.example .env.local
npm run start
```

For Android development builds, use a connected Android emulator or device after native generation:

```bash
npx expo run:android
```

This project follows Expo Continuous Native Generation. Generated `android/` and `ios/` folders remain untracked and are recreated by Expo when needed. `expo-dev-client` is installed so development builds are the baseline; Expo Go may still help with static UI checks but is not the production-equivalent workflow.

## Environment

Set the names declared in `.env.example` in a local `.env.local`. They are public Firebase Web configuration values, never service-account credentials. Do not commit local environment files.

`EXPO_PUBLIC_FIREBASE_FUNCTIONS_REGION` defaults to `us-central1`, matching the existing VerseGarden callable backend.

## Architecture

```text
src/app/                 Expo Router route definitions only
src/components/          shared layout and UI primitives
src/features/            feature-owned screens and future domain modules
src/providers/           lightweight app bootstrap/provider composition
src/services/firebase/   Firebase app, Auth, Firestore, Functions setup
src/services/persistence/ SQLite schema and UID-scoped preferences
src/theme/               design tokens
```

Firebase uses the JavaScript SDK, not Firebase Admin SDK or service accounts. Auth uses the supported React Native AsyncStorage persistence adapter. Firestore and Callable Functions use the same client-side contracts as the existing iOS and Admin Web clients.

### Auth and profile contract

The Android app observes Firebase Auth with `onAuthStateChanged`. It then reads only `users/{uid}`. Missing profiles are created with the existing iOS fields: `uid`, `email`, `displayName`, `nickname`, `onboardingCompleted`, `favoriteVerse`, `favoriteVerseId`, `selectedWritingPlanId`, `selectedTopics`, `createdAt`, and `updatedAt`.

`createdAt` and `updatedAt` use Firestore server timestamps. Onboarding completion updates the existing shared Firestore `onboardingCompleted` field and stores selected topics. The app does not use an Android-only onboarding profile schema.

The root gate is: Firebase/bootstrap initialization -> signed out auth routes -> profile loading -> onboarding or authenticated tabs. A profile fetch failure is retryable and is not treated as a missing profile.

SQLite is reserved for relational, offline-first records and sync metadata. AsyncStorage is reserved for small UID-scoped preferences. SecureStore is intentionally not installed in Phase 1 because there are no app-owned secrets to store; Firebase Auth persistence is handled by Firebase's supported adapter.

### Local Bible contract

The canonical source is [`../VerseGarden/Data/bible_krv_full.json`](../VerseGarden/Data/bible_krv_full.json). `assets/bible/bible_krv_full.json` is a derived, bundled asset: do not edit it manually. Refresh it with:

```bash
npm run sync:bible
```

Each verse keeps the shared iOS/Firebase-compatible identifier `${book}-${chapter}-${verse}` and canonical JSON order. `src/features/bible/bibleRepository.ts` builds one cached in-memory repository and search index only when the Verse experience is first opened. It supports text search, Korean book names, and structured references such as `창세기 1:1` and `마태복음 11`. The Verse tab debounces search for 250 ms and displays at most 12 results.

The Bible repository does not use Firestore or Callable Functions. The repository does not duplicate the text in SQLite. Repository metadata does not include attribution or license information for the KRV dataset; **Needs licensing verification** before an Android release.

### Personal verse activity contract

Authenticated personal activity uses the existing owner-only iOS paths and document fields:

- Likes: `users/{uid}/likedVerses/{verseId}` with `verseId` and `createdAt`. The verse ID document identity prevents duplicates.
- Verse lists: `users/{uid}/verseLists/{randomDocumentId}` and `items/{randomDocumentId}`. Lists retain iOS fields including `localId`, `ownerUserId`, timestamps, and item `book/chapter/verse` fields. A verse is only added once per list.
- Writing records: `users/{uid}/writingRecords/{randomDocumentId}` for free writing. It preserves `date`, `verseId`, book/chapter/verse, original and copied text, `completedAt`, source metadata, and Firestore timestamps. Free writing intentionally permits repeated copies.
- Writing plans: `users/{uid}/writingPlans/{randomDocumentId}` and `days/{randomDocumentId}`. Plan-writing records use the iOS-compatible deterministic document key from `planId + assignmentId + verseId`, so repeat completion updates one record instead of creating duplicates.

The Android provider subscribes only after the shared auth/profile gate reaches `ready`; it clears likes, lists, writing records, plans, and assignments on logout or UID changes. Firebase is the cross-platform source of truth for this Phase 4 personal data. There is no Android-only collection, service account, Admin SDK, or background sync engine.

Home resolves the profile `selectedWritingPlanId` using the iOS-compatible `localId`, then falls back deterministically to the newest active plan. It shows an unfinished today/next assignment only.

### QT and prayer contract

- QT records use the existing `users/{uid}/qtRecords/qt-{dateKey}` identity. Drafts and completion update the same record; completion requires at least one non-empty reflection, application, or prayer value. Records retain iOS-compatible content source, version, verse range, and optional community metadata fields, although Android does not submit Community QT data in this phase.
- Today QT resolves a published `dailyQuietTimes/{YYYY-MM-DD}` document first and resolves its verse range from the bundled Bible. If no valid published content is available, it uses a bundled local-Bible QT fallback. Bible text is never copied to a QT content document.
- Prayer records use `users/{uid}/prayerWritingRecords/{randomDocumentId}` with the iOS fields for source/template linkage, title snapshot, text, date, completion, and timestamps. Creating a free prayer also creates the matching private `users/{uid}/prayers/{randomDocumentId}` template, as iOS does.
- QT and prayer subscriptions begin only after the shared auth/profile gate is ready and clear immediately on logout or account changes.

## Manual Auth QA

1. Start a development build with a local `.env.local` configured from `.env.example`.
2. Log in with an existing VerseGarden email/password account and confirm a completed profile opens Home.
3. Register a disposable account manually, complete or skip onboarding, then confirm `users/{uid}` is created with the shared profile fields.
4. Log out, sign in again, and verify the profile belongs to the newly active UID.
5. Restart the Android app and verify Firebase Auth restores the session.
6. Use the password reset screen with an owned email address. Do not add production test accounts automatically.

## Manual Cross-Platform Verse QA

1. On iOS, save a known verse. Sign in to Android with the same account and verify its saved state and detail screen.
2. On Android, save and then remove a known verse. Verify both changes on iOS.
3. Open an existing iOS VerseList in Android; verify titles, memo, and item ordering. Create a small Android list and verify it on iOS.
4. Create a free Android writing record only with a deliberate test account. Verify iOS can read the verse, original text, copied text, and timestamp.
5. Complete one Android plan assignment, then retry its final verse. Verify iOS shows one deterministic plan writing record and one completed assignment.
6. Check that Home opens only the selected or deterministic active plan's unfinished today/next assignment.
7. Open Home QT, save a short draft, relaunch, and verify the same date record resumes. Complete it once and verify the Home QT state is complete without a duplicate `qtRecords` document.
8. Create, edit, then delete a prayer record with a deliberate test account. Confirm iOS can read its title, content, timestamps, and freeform source metadata.

## Quality checks

```bash
npm run typecheck
npm run lint
npm run doctor
npm run sync:bible
npm run validate:bible
npm run validate:phase4
npm run validate:phase5
npx expo config --type public
```

## Deferred

- Account Settings password change
- Profile editing and representative verse selection
- Community QT submission, Garden, Community, notifications, and widgets

## Next phase

Phase 5 will add QT and prayer while preserving the local Bible, personal verse activity, auth/profile, and session boundaries.
