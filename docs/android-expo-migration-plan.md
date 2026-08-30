# VerseGarden Android Expo Migration - Phase 0 Audit

## Scope and baseline

This is a read-only architecture audit of the native SwiftUI app. No Android project, Firebase resource, deployment, rule, index, function, iOS source, commit, or push was created by this phase.

Baseline checked on `main` at `790990d`. Existing worktree changes were preserved: Xcode user scheme metadata, `admin-web/src/lib/firebase.ts`, and the untracked duplicate `admin-web/src/app/admin/page 2.tsx`.

## Repository map

| Boundary | Actual location | Notes |
| --- | --- | --- |
| iOS app | `VerseGarden/`, `VerseGarden.xcodeproj` | SwiftUI, SwiftData, Firebase Auth/Firestore/Functions |
| iOS widget | `VerseGardenWidget/`, `VerseGarden/Shared/`, `VerseGarden/Services/Widget/` | WidgetKit plus App Group payload |
| Firebase backend | `functions/src/community/` | TypeScript callable Community/invite/submission functions |
| Firestore security | `firestore.rules`, `firestore.indexes.json`, `firebase-tests/` | owner-only private records; role-aware Community access |
| Admin web | `admin-web/` | Next.js Admin CMS and Community administration |
| Admin tooling | `admin-tools/` | one-time Custom Claim tooling; not mobile runtime |
| Bible/content data | `VerseGarden/Data/bible_krv_full.json`, `default_prayers.json` | bundled KRV Bible and prayer defaults |
| contracts | `docs/*contract.md`, `docs/daily-quiet-times-contract.md` | existing cross-surface contract documentation |

## iOS application architecture and navigation

`VerseGardenApp.swift` configures Firebase, creates one SwiftData container, creates app-level ObservableObject stores, and synchronizes on authenticated UID changes and foreground activation.

Root gates are: Firebase Auth loading -> signed out `AuthView` -> profile loading -> onboarding -> `RootTabView`. The five tabs are `VerseView`, `PrayerHomeView`, `HomeView`, `GardenView`, and `ProfileView`; each has a `NavigationStack`. Community is entered from Profile, not a tab.

`VerseGardenDeepLink.swift` handles `versegarden://verse/{verseId}`, `versegarden://write/{verseId}`, `versegarden://verse/today`, `versegarden://verse/favorite`, and `versegarden://profile`. `RootTabView` keeps a pending deep link until its destination tab/navigation stack is available. Android should retain that cold-start queue behavior.

### Proposed Expo Router shape

```
versegarden-expo/
  app/
    _layout.tsx
    (auth)/login.tsx
    (auth)/signup.tsx
    (auth)/reset-password.tsx
    onboarding/index.tsx
    (tabs)/verse/index.tsx
    (tabs)/prayer/index.tsx
    (tabs)/home/index.tsx
    (tabs)/garden/index.tsx
    (tabs)/profile/index.tsx
    verse/[verseId].tsx
    write/[verseId].tsx
    community/join.tsx
    community/index.tsx
    qt/today.tsx
  src/
    bible/ community/ features/ firebase/ models/ persistence/ stores/ theme/ ui/
```

Use a root auth/profile/onboarding gate before the tab group. Map custom links to `/verse/:verseId`, `/write/:verseId`, `/profile`, `/home`, and store pending links until authenticated navigation is ready.

## Feature inventory

| Feature | iOS entry / main files | Persistence and backend | Android pilot | Difficulty |
| --- | --- | --- | --- | --- |
| Email/password auth, signup, logout | `AuthView`, `LoginView`, `SignupView`, `AuthViewModel` | Firebase Auth | P0 | Medium |
| Reset/change password | `PasswordResetView`, `ChangePasswordView`, `AuthViewModel`, `AuthValidation` | Firebase Auth | P0 | Medium |
| Profile/nickname/onboarding | `Onboarding/*`, `ProfileView`, `UserProfileStore` | `users/{uid}`, UserDefaults migration marker | P0 | Medium |
| Home/today summary | `HomeView`, `TodayVerseService` | derived from records/content | P0 | Medium |
| Bible browse/read/search/detail | `VerseView`, Bible views, `BibleDataService`, `BibleSearchIndex` | bundled JSON | P0 | High (data/search) |
| Likes/favorite/lists | Verse detail/list views, `LikedVerseStore`, VerseList coordinators | `likedVerses`, profile, `verseLists/items` | P0 | Medium |
| Guided scripture writing | `WriteView`, `GuidedTypingTextView` | SwiftData + `writingRecords` | P0 | High (typing UX) |
| Writing plans | plan views/services | SwiftData + `writingPlans/days`, profile selection | P1 | High |
| Prayer/templates/history | `Views/Prayer/*`, `PrayerSyncCoordinator` | SwiftData + `prayers`, `prayerWritingRecords` | P0 core prayer; templates P1 | Medium |
| Daily QT | `TodayQuietTimeView`, `QTStore`, content services | UserDefaults + `qtRecords`; remote content | P0 | High |
| Garden/history | `GardenView`, `GrassView`, timeline builder | derived source records + local auxiliary log | P0 | Medium |
| Community join/detail | Profile/Community views, `CommunityStore`, `CommunityCallableService` | callables + Community documents | P0 | High |
| Community QT submission/retry | `CommunityQTSubmissionCoordinator` | private QT first, callable projection retry queue | P0 | High/privacy critical |
| Reminders | `ReminderScheduler`, settings | iOS notifications | P1; Expo replacement | Medium |
| Widgets/App Groups | `VerseGardenWidget`, Shared payload | WidgetKit/App Group | Skip Android pilot | iOS-specific |

No social login is implemented. No Android widget is required for the pilot.

## Design system mapping

Actual tokens/components are in `Views/Components/GardenUI.swift`: cream `#FAF7EF` background, off-white cards, deep/forest/sage greens, soft brown accent, 6/10/14/18/24 spacing, and 12/20/24/28 radii. Reusable components are `GardenCard`/`VGCard`, `GardenSectionHeader`/`VGSectionHeader`, `GardenPrimaryButton`, `SecondaryButton`, `AppInputField`, and `AppTextArea`.

Proposed React Native equivalents: `VGScreen`, `VGCard`, `VGSectionHeader`, `VGButton`, `VGTextField`, `VGTextArea`, `VGStatusBadge`, `VGEmptyState`, and `GardenHeatmap`. Preserve colors, generous card surfaces, and Korean copy hierarchy. Use Android-native back behavior, keyboard avoidance, modal/dialog semantics, and Material-compatible touch targets instead of emulating UIKit glass/tab bar appearance.

## Bible contract

`BibleDataService` loads `VerseGarden/Data/bible_krv_full.json` into `LocalBibleVerse`. The stable identity is exactly `${book}-${chapter}-${verse}`. `referenceText` is `${book} ${chapter}:${verse}`. Remote QT, favorites, writing, widgets, and deep links all depend on that ID.

The JSON contains `book`, `chapter`, `verse`, `testament`, and `text`. Search is an in-memory normalized index (`BibleSearchIndex`): Korean-aware case/diacritic folding, whitespace/reference compaction, `장`/`절` normalization, structured book/chapter/verse matching, a 250ms debounce, worker-style detached search, and a bounded result limit. Android must use the same ID/reference normalization and should build a cached in-memory index after lazy asset loading. Confirm Bible distribution licensing from source/project ownership before publishing Android; no license metadata was found in this audit.

## Persistence and synchronization

| Domain | iOS local source | Remote source | Android recommendation |
| --- | --- | --- | --- |
| Profile/favorite/selected plan | UserDefaults plus in-memory profile | `users/{uid}` | AsyncStorage cache + Firestore source of truth |
| Writing records/plans/lists/prayers | SwiftData | owner-only Firestore subcollections | expo-sqlite for relational/offline records, explicit sync metadata |
| Likes | UID-scoped UserDefaults | `users/{uid}/likedVerses/{verseId}` | AsyncStorage cache; Firestore merge keyed by verseId |
| QT records | UID-scoped UserDefaults | `users/{uid}/qtRecords/{recordId}` | expo-sqlite or AsyncStorage; use dateKey/id merge policy |
| Garden auxiliary `verseRead` | UID-scoped UserDefaults | none | AsyncStorage, local only |
| Community selection/retry queue | UID-scoped UserDefaults | membership resolved by callable | AsyncStorage; queue must contain identifiers only |

Use `expo-sqlite` for writing/prayer/QT/list data because records, sync flags, and deduplication are relational and can grow. Use AsyncStorage for small per-UID preferences and the submission queue. Use SecureStore only for secrets owned by the app; Firebase client auth persistence should use the supported React Native Firebase persistence adapter, not a custom token store.

Sync is local-first: local save/UI update -> Firestore/callable attempt -> retain local data on failure. Sync coordinators currently guard the active Firebase UID, tag legacy data, merge by remote ID/dedupe key, and avoid cross-account leakage. Android must replicate those boundaries.

## Firebase contract

Firebase project: `versegarden-34e7a`; callable region: `us-central1`. Personal collections are owner-only by `request.auth.uid == userId`.

| Path/function | Mobile direction | ID/fields and authorization |
| --- | --- | --- |
| `users/{uid}` | read/update/create own profile | uid, email, displayName/nickname, onboarding, favoriteVerse(Id), selectedWritingPlanId, topics, timestamps |
| `users/{uid}/likedVerses/{verseId}` | own CRUD | verse ID doc key, createdAt |
| `users/{uid}/writingRecords/{id}` | own CRUD | localId, verse metadata/text, completion timestamps; plan record IDs are deterministic `plan_*_assignment_*_verse_*` |
| `users/{uid}/prayers/{id}` | own CRUD | prayer templates |
| `users/{uid}/prayerWritingRecords/{id}` | own CRUD | completed prayer writing records |
| `users/{uid}/verseLists/{id}/items/{id}` | own CRUD | list/item metadata, iOS local UUID mapping |
| `users/{uid}/writingPlans/{id}/days/{id}` | own CRUD | plan and assignment state |
| `users/{uid}/qtRecords/{recordId}` | own CRUD | private answers, content identity, completion timestamps |
| `dailyQuietTimes/{dateKey}` | direct GET published; admin list/write | global remote QT; client must not list as member |
| `communities/{id}` / members | get own active Community, no direct membership writes | callable is authority for membership creation/roles |
| `communities/{id}/dailyQuietTimes/{dateKey}` | direct GET published for active member | managers create/edit; member must not list |
| `communities/{id}/qtSubmissions/{id}` | leader/admin get/list only | client never writes directly |
| `redeemCommunityInvite` | callable | `{ code }`, trusted transaction; normal signed-in user |
| `getMyCommunities` | callable | active membership summaries; ISO dates may have fractional seconds |
| `submitCommunityQT` | callable | approved projection only; idempotent by submission identity |

Firestore timestamps are native Timestamp values. Callable `getMyCommunities` returns ISO-8601 strings; Android must parse both fractional and non-fractional UTC forms.

## Community and QT contract

Roles are `member`, `leader`, `admin`; membership status is `active`, `removed`, `banned`, or `left`; Community status is `active`, `inactive`, or `archived`. `CommunityStore` obtains canonical active memberships from `getMyCommunities`, then stores only a UID-scoped selected-Community preference. A local ID is never authorization.

QT resolution is exact: active selected Community direct-GET at its IANA-timezone dateKey -> global `dailyQuietTimes/{Asia/Seoul dateKey}` direct-GET -> bundled local fallback. Remote content must be `published`, matching dateKey, and (for Community) matching communityId. Bible text is resolved locally from start/end verse IDs; do not store new remote verse text.

Private completion saves `QTRecord` locally, syncs it to `users/{uid}/qtRecords`, and derives one `qtCompleted` Garden activity. For Community source only, `submitCommunityQT` receives `{ communityId, dateKey, contentId, contentVersion, reflectionAnswer, applicationText }`. It must never receive `prayerText`, email, auth token, or a private record payload. The retry queue is UID-scoped and stores IDs/identity only; reconstruct allowed answers from the matching private record on retry. `alreadySubmitted` removes queue work and must not create another Garden activity.

## Garden and writing rules

Garden timeline merges `WritingRecord -> scriptureCopy`, `PrayerWritingRecord -> prayer`, `QTRecord(completedAt) -> qtCompleted`, liked-verse history, and local `GardenActivityStore` auxiliary events. `verseRead` may appear in recent activity but does not contribute to growth/streak/heatmap. QT, scripture copying, and prayer do. De-duplicate with source identity first; QT is one completion per day; scripture copies collapse by same-day verse/source.

Free writing intentionally creates independent history entries. Plan writing is idempotent per `planId + assignmentId + verseId`: local reconciliation uses the same duplicate key and Firestore uses a deterministic document ID. The current guided typing UI requires exact text/whitespace completion; Android should reproduce the behavioral rule, not UIKit text rendering.

## Expo and Firebase recommendation

Use Expo managed workflow with a Development Build as the baseline. Expo Go can accelerate static UI work, but production-compatible Auth persistence, notifications, and future native integrations make a development build the safer pilot path. Use Expo Router, `expo-linking`, AsyncStorage, expo-sqlite, SecureStore only where needed, and Expo Notifications later.

For Firebase choose the Firebase JavaScript SDK with React Native persistence for the pilot: it matches the Admin Web callable/Firestore contract and avoids immediate native Firebase module setup. Evaluate React Native Firebase only when native Crashlytics/Analytics/FCM requirements become P0; that requires a development build/EAS and is not needed to reproduce the current core data contracts.

## Risks

| Risk | Severity | Mitigation / test phase |
| --- | --- | --- |
| Verse ID drift | Critical | fixture test against bundled iOS JSON before Bible phase |
| dateKey/timezone mismatch | Critical | shared test vectors for Asia/Seoul and Community IANA zones |
| QT privacy projection | Critical | callable payload/network tests proving prayerText absence |
| cross-account local leakage | High | per-UID store reset/login-switch E2E |
| plan duplicate writes | High | deterministic ID and duplicate-key integration tests |
| Garden double counting | High | same-day/source dedupe fixtures |
| Timestamp parsing | High | ISO fractional/non-fractional and Firestore Timestamp tests |
| offline submission retry | High | queue identity/idempotency tests |
| Korean Bible search performance | High | corpus benchmark and debounce/result-limit tests |
| Android keyboard/back behavior | Medium | device QA on writing/QT flows |
| Firebase JS offline behavior | Medium | explicitly test persistence and reconnect behavior on Android |
| iOS widgets/App Group | Low for pilot | exclude from P0 |

## Delivery phases

1. **Foundation**: create isolated `versegarden-expo`, Expo Router, theme/UI primitives, Firebase JS config, build/test gate. Do not alter iOS/backend.
2. **Auth/profile/onboarding**: email/password, reset, profile gate, UID-scoped persistence.
3. **Bible**: generated/bundled Bible asset synchronized from the iOS source, browse/search/detail/deep links, identity fixture tests.
4. **Personal records**: likes, lists, guided writing and basic prayer, Firestore sync/dedupe.
5. **QT/Garden**: remote resolution, private QT records, Garden derived timeline and dateKey tests.
6. **Community**: membership discovery/redeem, Community QT, disclosure, trusted submission/retry and privacy tests.
7. **Plans/reminders/polish**: plan flow, notifications, accessibility, Android-specific navigation/keyboard QA.
8. **Cross-platform pilot QA**: same-account and multi-member iOS/Android/Admin Web E2E; internal distribution preparation.

Each phase must build on Android, run unit/contract tests, and avoid Firebase schema/rule/function changes unless separately approved.

## Pilot scope

**P0**: Auth, profile/onboarding, Home, Bible browse/search/detail, likes, direct scripture writing, basic prayer, QT, Garden, Profile, Community join/detail, Community QT/submission/retry, Firestore sync.

**P1**: writing plans, prayer template management/history refinement, notifications, sharing/export, better offline conflict UI.

**P2**: Android widget, advanced analytics/crash reporting, Android-native integrations.

**Skip initially**: WidgetKit/App Group behavior and iOS-specific tab-bar visual effects.

## Cross-platform E2E acceptance

- Like a verse on Android; verify iOS shows the same `likedVerses/{verseId}` state.
- Complete Android Community QT; verify one private QTRecord, one approved submission, no prayer/email in submission, Admin Web participation update, and one Garden QT activity.
- Verify Android plan writing does not duplicate an iOS-created plan assignment record.
- Verify same account across devices, logout/login UID changes, inactive/removed membership, timezone boundary, offline completion/retry, and duplicate callable retry.
- Verify member cannot list Community QT/submissions and Android never directly writes memberships or shared submissions.

## Distribution recommendation

Use Expo Development Builds for engineering/QA, then EAS internal distribution for church testers before Google Play Internal Testing. Later Play testing requires a Play Console account, Android app signing, package/application ID, privacy disclosures, and tester management. No accounts, keys, or publication were configured in Phase 0.

## Complexity and critical path

Low: theme primitives, static screens, basic profile UI. Medium: Auth, likes, prayer, Garden presentation. High: Bible search corpus, SwiftData replacement/sync, QT resolution, Community authorization/submission privacy, writing plans. The critical path is stable Bible identity -> Auth/profile -> private record sync -> QT -> Community QT submission/privacy -> cross-platform E2E.
