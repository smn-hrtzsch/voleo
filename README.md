# Voleo

Voleo is a free, open-source prediction game app for the FIFA World Cup 2026. It is designed for private leagues between friends, automatic result tracking, and realtime leaderboard updates.

## Stack

- Flutter for Android and iOS from one codebase.
- Firebase Spark for Auth and Firestore realtime sync.
- OpenLigaDB as the no-cost World Cup 2026 match/result source.
- GitHub Actions for scheduled result imports and scoring recalculation.

## Current State

This repository contains the first MVP foundation:

- App shell and main screens.
- Anonymous-first onboarding with optional email recovery planned.
- Invite-code league flow.
- Match list, tip entry, leaderboard, and profile screens.
- Classic scoring engine.
- Result-sync script with dry-run support.
- CI workflows for Flutter and scheduled result sync.
- Firestore security rules for private leagues and locked tips.

Firebase project files are intentionally not committed. Add platform config through FlutterFire before using the cloud backend.

## Package IDs

- Android: `de.capycode.voleo`
- iOS: `de.capycode.voleo`

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Result Sync

Dry run:

```sh
npm install
npm run sync:results -- --dry-run
```

GitHub Actions uses the same script on a schedule. A future Firebase service account secret will be required for production writes.

## Cost Model

The MVP avoids paid runtime dependencies:

- Firebase Spark requires no payment method for the intended MVP services.
- OpenLigaDB is free and unauthenticated for reads.
- GitHub Actions is used for scheduled jobs instead of paid backend workers.

Publishing through the public app stores is separate from app operation and may require developer account fees.
