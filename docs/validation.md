# Validation · 5 November 2026

Environment: Flutter 3.41.6 / Dart 3.11.4, Java 17, Kotlin 2.4.21, Android emulator with API 37.1 (ARM64).

- `flutter analyze`: no issues.
- `flutter test`: all 5 unit tests passed (room-code validation, seed/pseudonym consistency, per-room identity reuse, persisted message history, date boundaries).
- Android integration test: passed against the configured live Firebase project. Verified create-room flow, live two-client replies, membership count, 37 messages through 30-message pagination, reopening with the same identity offline, queued offline send with server timestamp after reconnect, joining another room through the code field with a fresh API-generated identity, theme switching, and returning to the original identity.
- Rules checks: nonmember reads, spoofed sender names, and message edits were rejected.
- `firebase deploy --only firestore`: rules compiled and deployed successfully.
- `flutter build apk --release --split-per-abi`: built ARM64, ARMv7, and x86_64 APKs.

To regenerate UI screenshots:

```sh
flutter drive --driver=test_driver/workflow_driver.dart \
  --target=integration_test/workflow_test.dart \
  -d emulator-5554 --dart-define=CAPTURE_DEMO=true
```

The workflow video records this actual Android test flow. The second participant runs in an independent Firebase client within the test app; it has a separate anonymous UID and Firestore instance. Offline mode is exercised by disabling the app's Firestore network before recreating its widget tree, then restoring the network and checking the server commit. The test leaves its generated rooms in Firestore for review.
