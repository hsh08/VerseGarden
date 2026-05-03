# Firebase Setup

1. Create a Firebase project in the Firebase console.
2. Register the iOS app with bundle ID `com.sanghyuk.VerseGarden`.
3. Enable the `Email/Password` provider in `Authentication > Sign-in method`.
4. Download `GoogleService-Info.plist`.
5. Add `GoogleService-Info.plist` to the `VerseGarden` target in Xcode.
6. Build and run the app again.

The real `GoogleService-Info.plist` is intentionally not committed here because it is project-specific secret/configuration material.

