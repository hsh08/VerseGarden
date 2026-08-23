# VerseGarden Admin Web

Admin Web for managing `dailyQuietTimes/{dateKey}` content.

## Setup

1. Copy `.env.local.example` to `.env.local`.
2. Fill in the Firebase Web SDK config from the same Firebase project used by the iOS app.
3. Do not place service account JSON files in this project.
4. Run:

```sh
npm install
npm run dev
```

## Bible Data

`src/generated/bible_krv_full.json` is generated from the iOS source file:

`../VerseGarden/Data/bible_krv_full.json`

Do not edit generated Bible JSON manually. Run:

```sh
npm run sync:bible
```

## Security

Admin access is based on Firebase Auth Custom Claims:

```json
{ "admin": true }
```

Firestore Rules remain the final authorization layer.
