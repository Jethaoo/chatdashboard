# Multi-chat

`Multi-chat` is a Flutter + Firebase customer support chat app with two role-based experiences:

- `CustomerPortal` for end users
- `AdminDashboard` for support/admin users

The web app is the primary deployment target. Customers and admins both use the same app, and the UI is selected from the signed-in user's Firestore profile role.

Live app: [https://chatboard-52d74.web.app](https://chatboard-52d74.web.app)

## Features

- Email/password sign in and sign up
- Forgot/reset password flow
- Role-based routing for customer vs admin access
- Persistent customer conversations in Cloud Firestore
- Resolved and reopened chat sessions
- Message sender names and timestamps
- Date separators in the chat timeline
- User settings for display name, password, and theme mode
- Light and dark mode support
- Firebase Hosting deployment for the web app

## Tech Stack

- Flutter
- Firebase Auth
- Cloud Firestore
- Firebase Hosting
- Provider
- Shared Preferences

## Project Status

- Web is the recommended platform for both customers and admins
- Windows desktop support is present, but Firebase on Windows has shown native instability on some setups
- The app is ready to publish to GitHub as a Firebase-backed Flutter project

## Getting Started

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) with SDK compatible with `^3.10.4`
- A Firebase project with:
  - Authentication -> Email/Password enabled
  - Cloud Firestore enabled
  - Firebase Hosting enabled if you want to deploy the web app
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)

### Install dependencies

```bash
flutter pub get
```

### Configure Firebase

This repo already contains `lib/firebase_options.dart`, but if you want to point the app to your own Firebase project, re-run FlutterFire:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Make sure web is included. If you want desktop support, include Windows too.

### Run locally

Recommended:

```bash
flutter run -d chrome
```

Supported routes:

- `/` -> normal sign-in flow
- `/chat` -> customer route
- `/admin` -> admin route

Optional Windows desktop run:

```bash
flutter run -d windows --release
```

## Firebase Data Model

### `users/{uid}`

Stores user profile data:

- `uid`
- `email`
- `name`
- `role`

Newly created users default to `role: "customer"`.

### `sessions/{sessionId}`

Stores each support conversation:

- `customerId`
- `customerEmail`
- `status`
- `lastActivity`

### `sessions/{sessionId}/messages/{messageId}`

Stores messages:

- `text`
- `senderId`
- `senderName`
- `timestamp`

## Admin Access

Admin access is controlled by the Firestore user document, not by a hardcoded client flag.

To promote a user:

1. Open Firestore in Firebase Console
2. Open `users/{uid}`
3. Change `role` from `customer` to `admin`

Security rules prevent customers from promoting themselves.

## Firestore Rules and Indexes

This repo includes:

- `firestore.rules`
- `firestore.indexes.json`

Deploy them with:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Web Build and Deploy

This project uses Firebase Hosting and includes SPA rewrites in `firebase.json`.

Build the web app with local web engine resources:

```bash
flutter build web --no-web-resources-cdn
```

Deploy Hosting:

```bash
firebase deploy --only hosting
```

## Testing and Quality Checks

```bash
flutter analyze
flutter test
```

The repository also includes a GitHub Actions workflow at `.github/workflows/flutter-ci.yml` that runs `flutter analyze` and `flutter test` on pushes and pull requests.

## Project Structure

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App bootstrap, routing, theme wiring, Firebase initialization |
| `lib/models/` | App data models |
| `lib/services/` | Auth, chat, and theme services |
| `lib/views/` | Login, customer chat, admin dashboard, settings |
| `lib/widgets/` | Shared UI widgets |
| `lib/utils/` | Formatting, auth error mapping, UI feedback helpers |
| `web/` | Web shell files such as `index.html` and `manifest.json` |
| `firestore.rules` | Firestore security rules |
| `firestore.indexes.json` | Firestore composite indexes |
| `firebase.json` | Firebase Hosting and Firestore config |

## Windows Desktop Note

Windows support is still included, but the recommended production path is web. On some machines, FlutterFire on Windows can crash in native code (`ucrtbase.dll` / `0xc0000409`). If that happens, prefer the hosted web app for admin usage.

## GitHub Publishing Notes

The project is now set up for a cleaner GitHub publish:

- build and cache folders are ignored in `.gitignore`
- Firebase local cache files are ignored
- a CI workflow is included
- the README matches the current app behavior and deployment flow

Before publishing publicly, you may still want to:

1. Choose and add a `LICENSE`
2. Decide whether you want to keep the current Firebase project identifiers in the repo
3. Add screenshots or a short demo section if you want a stronger GitHub landing page

## License

This project is licensed under the MIT License. See `LICENSE`.
